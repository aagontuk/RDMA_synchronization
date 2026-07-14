#!/usr/bin/env bash
# -------------------------------------------------------------------------------------
# Runs locking_benchmark with 1 storage node (this machine) and up to 4 client nodes
# (node-1..node-4), then records aggregate client throughput per (read %, zipf skew,
# padding, lock count) workload phase into a CSV file:
#   total_client_threads,read_pct,zipf,padding,lock_count,aggregate_throughput_tx_per_sec
#
# The client binary is expected to sweep read ratios {100, 95, 50, 0} and zipf skew
# {0, 0.99, 1, 1.5, 2, 2.5} internally in a single run (see frontend/locking_benchmark.cpp).
# This script runs the whole sweep once per value in PADDING_VALUES (both "with" and
# "without" padding by default), fans the client threads out evenly across the client
# nodes, waits for each run to finish, pulls each node's per-second -csv output back,
# and sums the steady-state tx/sec of each workload phase across all nodes.
#
# -padding must match between the storage node and every client -- the tuple byte
# offset (t_i * TUPLE_SIZE + t_i * padding) is computed the same way on both sides, so
# a mismatch would corrupt the address layout.
#
# Results/raw directories are inferred from wherever OUT_CSV points: raw per-node logs
# and csvs are written to <dirname of OUT_CSV>/raw/padding_<N>/.
#
# Usage:
#   scripts/run_locking_benchmark.sh [--out-csv=PATH | -o PATH]
#
# Overridable via environment variables:
#   SERVER_IP, CLIENT_NODES (space separated "host:ip" pairs), TOTAL_THREADS,
#   LOCK_COUNT, DRAM_GB, SOCKETS, PADDING_VALUES (space separated list), OUT_CSV
#
# --out-csv/-o (if given) takes precedence over the OUT_CSV environment variable.
# -------------------------------------------------------------------------------------
set -euo pipefail

SCRIPT_DIR=$(dirname "$(readlink -f "$0")")
BIN="${SCRIPT_DIR}/../build/frontend/locking_benchmark"

SERVER_IP=${SERVER_IP:-10.10.1.1}
# "hostname:ip" pairs -- hostname is used for ssh, ip is passed as -ownIp
CLIENT_NODES=${CLIENT_NODES:-"node-1:10.10.1.2 node-2:10.10.1.3 node-3:10.10.1.4 node-4:10.10.1.5"}
read -r -a CLIENT_NODE_ARR <<< "${CLIENT_NODES}"
NUM_NODES=${#CLIENT_NODE_ARR[@]}

TOTAL_THREADS=${TOTAL_THREADS:-128}
LOCK_COUNT=${LOCK_COUNT:-20000000}
DRAM_GB=${DRAM_GB:-10}
SOCKETS=${SOCKETS:-1}
# "without padding" (0) and "with padding" (8, the binary's own default) by default
PADDING_VALUES=${PADDING_VALUES:-"0 8"}
read -r -a PADDING_ARR <<< "${PADDING_VALUES}"

DEFAULT_RESULTS_DIR="${SCRIPT_DIR}/results"
OUT_CSV=${OUT_CSV:-"${DEFAULT_RESULTS_DIR}/locking_benchmark_aggregate.csv"}
CSV_HEADER="total_client_threads,read_pct,zipf,padding,lock_count,aggregate_throughput_tx_per_sec"

# -------------------------------------------------------------------------------------
# CLI flags
# -------------------------------------------------------------------------------------
while [[ $# -gt 0 ]]; do
   case "$1" in
      --out-csv=*)
         OUT_CSV="${1#*=}"
         shift
         ;;
      --out-csv|-o)
         OUT_CSV="$2"
         shift 2
         ;;
      -h|--help)
         echo "Usage: $0 [--out-csv=PATH | -o PATH]"
         exit 0
         ;;
      *)
         echo "Unknown argument: $1" >&2
         echo "Usage: $0 [--out-csv=PATH | -o PATH]" >&2
         exit 1
         ;;
   esac
done

# Results/raw directories are inferred from wherever OUT_CSV ends up pointing, so a
# custom --out-csv/-o location gets its own raw/ subdirectory alongside it instead of
# always using scripts/results/raw.
RESULTS_DIR=$(dirname "${OUT_CSV}")
RAW_DIR="${RESULTS_DIR}/raw"

if (( TOTAL_THREADS % NUM_NODES != 0 )); then
   echo "TOTAL_THREADS (${TOTAL_THREADS}) must be evenly divisible by number of client nodes (${NUM_NODES})" >&2
   exit 1
fi
WORKER_PER_NODE=$((TOTAL_THREADS / NUM_NODES))

mkdir -p "${RAW_DIR}"

if [[ ! -x "${BIN}" ]]; then
   echo "Binary not found or not executable: ${BIN}" >&2
   exit 1
fi

# -------------------------------------------------------------------------------------
# If OUT_CSV already exists with an older header (pre-padding-column, or pre-lock_count
# column), migrate it in place rather than leaving a ragged/inconsistent CSV:
#   - rows written before the padding column existed always used the binary's default
#     padding of 8
#   - rows written before the lock_count column existed always used this invocation's
#     LOCK_COUNT (each results file has consistently been used for one dataset scale)
# -------------------------------------------------------------------------------------
HEADER_V1="total_client_threads,read_pct,zipf,aggregate_throughput_tx_per_sec"
HEADER_V2="total_client_threads,read_pct,zipf,padding,aggregate_throughput_tx_per_sec"
if [[ -f "${OUT_CSV}" ]]; then
   CURRENT_HEADER="$(head -n 1 "${OUT_CSV}" | tr -d '\r\n')"
   if [[ "${CURRENT_HEADER}" == "${HEADER_V1}" ]]; then
      echo "Migrating ${OUT_CSV}: backfilling padding=8 and lock_count=${LOCK_COUNT} for historical rows"
      TMP_MIGRATE=$(mktemp)
      {
         echo "${CSV_HEADER}"
         tail -n +2 "${OUT_CSV}" | tr -d '\r' | awk -F',' -v lc="${LOCK_COUNT}" 'BEGIN{OFS=","} {print $1,$2,$3,8,lc,$4}'
      } > "${TMP_MIGRATE}"
      mv "${TMP_MIGRATE}" "${OUT_CSV}"
   elif [[ "${CURRENT_HEADER}" == "${HEADER_V2}" ]]; then
      echo "Migrating ${OUT_CSV}: backfilling lock_count=${LOCK_COUNT} for historical rows"
      TMP_MIGRATE=$(mktemp)
      {
         echo "${CSV_HEADER}"
         tail -n +2 "${OUT_CSV}" | tr -d '\r' | awk -F',' -v lc="${LOCK_COUNT}" 'BEGIN{OFS=","} {print $1,$2,$3,$4,lc,$5}'
      } > "${TMP_MIGRATE}"
      mv "${TMP_MIGRATE}" "${OUT_CSV}"
   fi
fi

# -------------------------------------------------------------------------------------
# Cleanup on exit/interrupt
# -------------------------------------------------------------------------------------
SERVER_PID=""
cleanup() {
   if [[ -n "${SERVER_PID}" ]] && kill -0 "${SERVER_PID}" 2>/dev/null; then
      kill "${SERVER_PID}" 2>/dev/null || true
   fi
   for node_ip in "${CLIENT_NODE_ARR[@]}"; do
      node="${node_ip%%:*}"
      ssh -o BatchMode=yes -o ConnectTimeout=5 "${node}" "pkill -f locking_benchmark" 2>/dev/null || true
   done
}
trap cleanup EXIT INT TERM

for PADDING in "${PADDING_ARR[@]}"; do
   echo "==============================================================================="
   echo "Running locking_benchmark: ${TOTAL_THREADS} total client threads across ${NUM_NODES} node(s) (${WORKER_PER_NODE} each), padding=${PADDING}"
   echo "==============================================================================="

   RUN_DIR="${RAW_DIR}/padding_${PADDING}"
   mkdir -p "${RUN_DIR}"

   # ----------------------------------------------------------------------------------
   # Clean up any stale processes from a previous run before starting
   # ----------------------------------------------------------------------------------
   pkill -f "locking_benchmark .*-storage_node" 2>/dev/null || true
   for node_ip in "${CLIENT_NODE_ARR[@]}"; do
      node="${node_ip%%:*}"
      ssh -o BatchMode=yes -o ConnectTimeout=5 "${node}" "pkill -f locking_benchmark" 2>/dev/null || true
   done

   # ----------------------------------------------------------------------------------
   # Start storage node
   # ----------------------------------------------------------------------------------
   SERVER_LOG="${RUN_DIR}/server.log"
   "${BIN}" -ownIp="${SERVER_IP}" -storage_node -dramGB="${DRAM_GB}" -lock_count="${LOCK_COUNT}" \
      -padding="${PADDING}" -all_worker="${TOTAL_THREADS}" -worker="${TOTAL_THREADS}" > "${SERVER_LOG}" 2>&1 &
   SERVER_PID=$!
   sleep 3
   if ! kill -0 "${SERVER_PID}" 2>/dev/null; then
      echo "Storage node failed to start, see ${SERVER_LOG}" >&2
      cat "${SERVER_LOG}" >&2
      exit 1
   fi

   # ----------------------------------------------------------------------------------
   # Start clients on every node in parallel and wait for all of them to finish
   # ----------------------------------------------------------------------------------
   CLIENT_PIDS=()
   CLIENT_CSVS=()
   for node_ip in "${CLIENT_NODE_ARR[@]}"; do
      node="${node_ip%%:*}"
      ip="${node_ip##*:}"
      remote_csv="/tmp/locking_benchmark_${node}_padding${PADDING}.csv"
      local_csv="${RUN_DIR}/${node}.csv"
      rm -f "${local_csv}"
      ssh -o BatchMode=yes "${node}" \
         "rm -f ${remote_csv}; ${BIN} -ownIp=${ip} -lock_count=${LOCK_COUNT} \
            -all_worker=${TOTAL_THREADS} -worker=${WORKER_PER_NODE} -sockets=${SOCKETS} \
            -padding=${PADDING} \
            -write_combining -speculative_read -order_release -csv -csvFile=${remote_csv}" \
         > "${RUN_DIR}/${node}.log" 2>&1 &
      CLIENT_PIDS+=("$!")
      CLIENT_CSVS+=("${node}:${ip}:${remote_csv}:${local_csv}")
   done

   FAILED=0
   for pid in "${CLIENT_PIDS[@]}"; do
      if ! wait "${pid}"; then
         FAILED=1
      fi
   done
   if (( FAILED != 0 )); then
      echo "One or more client runs failed (padding=${PADDING}), check ${RUN_DIR}/*.log" >&2
      exit 1
   fi

   # Pull each node's csv back locally
   for entry in "${CLIENT_CSVS[@]}"; do
      node="${entry%%:*}"
      rest="${entry#*:}"
      ip="${rest%%:*}"
      rest="${rest#*:}"
      remote_csv="${rest%%:*}"
      local_csv="${rest#*:}"
      ssh -o BatchMode=yes "${node}" "cat ${remote_csv}" > "${local_csv}"
   done

   # Storage node exits on its own once all clients disconnect
   wait "${SERVER_PID}"
   SERVER_PID=""

   echo "Storage node result (padding=${PADDING}):"
   tail -n 3 "${SERVER_LOG}"

   # -----------------------------------------------------------------------------------
   # Aggregate per-node CSVs into aggregate throughput per (read %, zipf) phase
   # -----------------------------------------------------------------------------------
   mkdir -p "${RESULTS_DIR}"
   python3 - "${OUT_CSV}" "${TOTAL_THREADS}" "${PADDING}" "${LOCK_COUNT}" "${CSV_HEADER}" "${RUN_DIR}"/*.csv <<'PYEOF'
import csv
import sys
import os

out_csv, total_threads, padding, lock_count, csv_header = sys.argv[1], sys.argv[2], sys.argv[3], sys.argv[4], sys.argv[5]
node_csvs = sys.argv[6:]

def col(row, name):
    for k, v in row.items():
        if k is not None and k.strip() == name:
            return v
    return None

# phases[(read_ratio, zipf)] -> list of per-node steady-state averages
phases = {}

for path in node_csvs:
    if not os.path.exists(path) or os.path.getsize(path) == 0:
        continue
    # blocks of consecutive rows sharing the same (read_ratio, zipf)
    block_key = None
    block_vals = []

    def flush():
        if block_key is None or not block_vals:
            return
        # drop the first sample of the phase (ramp-up) like process_results.py does
        steady = block_vals[1:] if len(block_vals) > 1 else block_vals
        if not steady:
            return
        avg = sum(steady) / len(steady)
        phases.setdefault(block_key, []).append(avg)

    with open(path, newline='') as f:
        reader = csv.DictReader(f, skipinitialspace=True)
        for row in reader:
            tx_str = col(row, 'tx/sec')
            ratio_str = col(row, 'ReadRatio')
            zipf_str = col(row, 'ZipfFactor')
            if tx_str is None or ratio_str is None or zipf_str is None:
                continue
            try:
                tx = float(tx_str)
                ratio = int(float(ratio_str))
                zipf = float(zipf_str)
            except ValueError:
                continue
            key = (ratio, zipf)
            if key != block_key:
                flush()
                block_key = key
                block_vals = []
            block_vals.append(tx)
        flush()

file_exists = os.path.exists(out_csv)
with open(out_csv, 'a', newline='') as f:
    writer = csv.writer(f, lineterminator='\n')
    if not file_exists:
        writer.writerow(csv_header.split(','))
    for (ratio, zipf), avgs in phases.items():
        aggregate = sum(avgs)
        writer.writerow([total_threads, ratio, zipf, padding, lock_count, f"{aggregate:.2f}"])
        print(f"padding={padding} lock_count={lock_count} threads={total_threads} read%={ratio} zipf={zipf} aggregate_tx_per_sec={aggregate:,.0f}")
PYEOF

done

echo "Results appended to ${OUT_CSV}"

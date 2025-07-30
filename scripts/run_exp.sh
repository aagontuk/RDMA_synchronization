set -xeuo pipefail

# Script directory
SCRIPT_DIR=$(dirname "$(readlink -f "$0")")

# Benchmark binary path
BIN="${SCRIPT_DIR}/../build/frontend/optmistic_benchmark"

# Bench configurations
NUM_SOCKETS=1
RUN_TIME=20
LOCK_COUNT=2000

LOG_FILE="${SCRIPT_DIR}/../client_stats"
RESULTS="${SCRIPT_DIR}/results.csv"

benchmarks=("pessimistic" "broken" "rc" "rcopt")
sizes=(64 128 256 512 1024 2048 4096 8192)
threads=(1 2 4 8 16)

echo "size,num_locks,threads,bench,throughput" > "${RESULTS}"

for size in ${sizes[@]}; do
  for bench in ${benchmarks[@]}; do
    for threads in 1 2 4 8 16; do
      retry=true
      while ${retry}; do
        # Run server
        if [ "$bench" == "rcopt" ]; then
          ${BIN} -ownIp=10.10.1.1 -storage_node -dramGB=10 -all_worker $threads -worker $threads -rcopt &
          s_pid=$!
        else 
          ${BIN} -ownIp=10.10.1.1 -storage_node -dramGB=10 -all_worker $threads -worker $threads &
          s_pid=$!
        fi

        # Wait for server to start
        sleep 5

        # Run client over ssh
        ssh node1 "${BIN} -ownIp=10.10.1.2 -run_for_seconds=$RUN_TIME -readratios 100 -${bench} -block_size $size -worker $threads -all_worker $threads -sockets $NUM_SOCKETS" -csv -csvFile ${LOG_FILE}.csv -lock_count $LOCK_COUNT
        
        sleep 1

        avg=$(python3 ${SCRIPT_DIR}/process_results.py --file "${LOG_FILE}.csv")
        
        # Check if avg is a valid number
        if [[ $avg =~ ^[0-9]+(\.[0-9]+)?$ ]]; then
          retry=false
        else
          echo "Retrying due to invalid average throughput: $avg"
          wait $s_pid
          rm "${LOG_FILE}.csv"
          retry=true
        fi
      done
      echo "${size},${LOCK_COUNT},${threads},${bench},${avg}" >> "${RESULTS}"

      # Wait for server to finish
      wait $s_pid
      rm "${LOG_FILE}.csv"
    done
  done
done

set -xeuo pipefail

# Script directory
SCRIPT_DIR=$(dirname "$(readlink -f "$0")")

# Benchmark binary path
BIN="${SCRIPT_DIR}/../build/frontend/optmistic_benchmark"

# Bench configurations
NUM_SOCKETS=1
RUN_TIME=20
BLOCK_SIZE=1024

LOG_FILE="${SCRIPT_DIR}/../client_stats"
RESULTS="${SCRIPT_DIR}/results.csv"

benchmarks=("pessimistic" "broken" "rc" "rcopt")

echo "size,threads,bench,throughput" > "${RESULTS}"

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
      ssh node1 "${BIN} -ownIp=10.10.1.2 -run_for_seconds=$RUN_TIME -readratios 100 -${bench} -block_size $BLOCK_SIZE -worker $threads -all_worker $threads -sockets $NUM_SOCKETS" -csv -csvFile ${LOG_FILE}.csv
      
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
    echo "${BLOCK_SIZE},${threads},${bench},${avg}" >> "${RESULTS}"

    # Wait for server to finish
    wait $s_pid
    rm "${LOG_FILE}.csv"
  done
done

set -euo pipefail

# Script directory
SCRIPT_DIR=$(dirname "$(readlink -f "$0")")

# Benchmark binary path
BIN="${SCRIPT_DIR}/../build/frontend/optmistic_benchmark"

# Bench configurations
NUM_SOCKETS=1
RUN_TIME=20
LOCK_COUNT=2000

LOG_FILE="${SCRIPT_DIR}/../client_stats"
RESULTS="${SCRIPT_DIR}/results/set2/results_sm110p_set2.csv"

benchmarks=("pessimistic:1" "pessimistic:32" "broken:1" "broken:32" "rc:32" "rcopt:32" "farm:1:nomemcpy" "farm:32:nomemcpy" "farm:1:memcpy" "farm:32:memcpy")
# For FaRM broken benchmark
# First checkout to main and rebuild then Run this separately
# benchmarks=("farm:1:broken")
sizes=(64 128 256 512 1024 2048 4096 8192)
thread_configs=(1 2 4 8 16)

echo "size,num_locks,threads,bench,throughput" > "${RESULTS}"

for size in ${sizes[@]}; do
  for bench in ${benchmarks[@]}; do
    for threads in ${thread_configs[@]}; do
      retry=true
      IFS=':' read -r -a bench_params <<< "$bench"
      bench_name=${bench_params[0]}
      bench_batch_size=${bench_params[1]}
      if [ ${#bench_params[@]} -gt 2 ]; then
        bench_extra=${bench_params[2]}
      else
        bench_extra="nomemcpy"
      fi

      echo "Running benchmark: size=$size, locks=$LOCK_COUNT, threads=$threads, bench=$bench_name, batch_size=$bench_batch_size, extra=$bench_extra"

      while ${retry}; do
        # Run server
        if [ "$bench_name" == "rcopt" ]; then
          ${BIN} -ownIp=10.10.1.1 -storage_node -dramGB=10 -all_worker $threads -worker $threads -rcopt &
          s_pid=$!
        else 
          ${BIN} -ownIp=10.10.1.1 -storage_node -dramGB=10 -all_worker $threads -worker $threads &
          s_pid=$!
        fi

        # Wait for server to start
        sleep 5

        # Run client over ssh
        # FaRM broken
        if [ "$bench_extra" == "broken" ]; then
          ssh node1 "${BIN} -ownIp=10.10.1.2 -run_for_seconds=$RUN_TIME -readratios 100 -${bench_name} -block_size $size -worker $threads -all_worker $threads -sockets $NUM_SOCKETS" -csv -csvFile ${LOG_FILE}.csv -lock_count $LOCK_COUNT
        else
          ssh node1 "${BIN} -ownIp=10.10.1.2 -run_for_seconds=$RUN_TIME -readratios 100 -${bench_name} -block_size $size -worker $threads -all_worker $threads -sockets $NUM_SOCKETS" -csv -csvFile ${LOG_FILE}.csv -lock_count $LOCK_COUNT -batch_size $bench_batch_size -${bench_extra}
        fi
        
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

      if [ "$bench_name" == "farm" ]; then
        # For FaRM broken
        if [ "$bench_extra" = "broken" ]; then
          echo "${size},${LOCK_COUNT},${threads},${bench_name},${avg}" >> "${RESULTS}"
        else
          echo "${size},${LOCK_COUNT},${threads},${bench_name}_fixed_${bench_extra}_batch_${bench_batch_size},${avg}" >> "${RESULTS}"
        fi
      else
        echo "${size},${LOCK_COUNT},${threads},${bench_name}_batch_${bench_batch_size},${avg}" >> "${RESULTS}"
      fi

      # Wait for server to finish
      wait $s_pid
      rm "${LOG_FILE}.csv"
    done
  done
done

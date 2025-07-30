import csv
import os
import argparse

COL_NAME="tx/sec "
FILE_NAME="client_stats.csv"
NUM_ENTRIES=10

# Script directory full path
SCRIPT_DIR = os.path.abspath(os.path.dirname(__file__))
FILE_PATH = "".join([SCRIPT_DIR, "/../", FILE_NAME])

def average(csv_file_path):
    tx_sec_values = []
    with open(csv_file_path, newline='') as csvfile:
        reader = csv.DictReader(csvfile, skipinitialspace=True)
        
        for row in reader:
            tx_sec_str = row.get(COL_NAME)
            if tx_sec_str is not None:
                try:
                    tx_val = float(tx_sec_str)
                    if tx_val > 0:  # skip zeros and -nan
                        tx_sec_values.append(tx_val)
                except ValueError:
                    continue  # skip rows with non-numeric or invalid tx/sec

    if len(tx_sec_values) < NUM_ENTRIES:
        print("Not enough valid tx/sec values to compute average.")
        return None

    avg = sum(tx_sec_values[-NUM_ENTRIES:]) / NUM_ENTRIES
    return avg

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Process CSV file to compute average tx/sec.")
    parser.add_argument('--file', type=str, default=FILE_PATH, help='Path to the CSV file to process.')
    args = parser.parse_args()

    if os.path.exists(args.file):
        avg = average(args.file)
        if avg is None:
            print("No valid tx/sec values found.")
        else:
            print(avg / 10**6)
    else:
        print(f"File not found: {FILE_PATH}")

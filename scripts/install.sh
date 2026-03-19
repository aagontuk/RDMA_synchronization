#!/bin/bash

########################################
# Installation script for Ubuntu 22.04 #
########################################

N_HUGE_PAGE=10240

n_huge=$(cat /proc/meminfo | grep -i HugePages_Total | awk '{print $2}')
s_huge=$(cat /proc/meminfo | grep -i Hugepagesize | awk '{print $2,$3}')
  
SCRIPT_DIR=$(dirname "$(realpath "$0")")

# Setup hugepages
function setup_hugepages() {
  if [ ! $n_huge -eq $N_HUGE_PAGE ]; then
    echo "ERROR: No hugepages found"
    echo "Setting up hugepages"
    echo "${N_HUGE_PAGE}" | sudo tee /proc/sys/vm/nr_hugepages
  else
    echo "Found ${n_huge} pages of size ${s_huge}"
  fi
}

function system_setup() {
  vendor=$(grep -m 1 "vendor_id" /proc/cpuinfo)

  sudo apt update
  sudo apt install -y linux-tools-common linux-tools-`uname -r` htop

  # Install plot packages
  sudo apt install -y python3-pip
  pip install matplotlib pandas

  if [[ "$vendor" == *"GenuineIntel"* ]]; then
    # Set scaling governor to performance
    sudo cpupower frequency-set --governor performance

    # Disable turbo
    echo "1" | sudo tee /sys/devices/system/cpu/intel_pstate/no_turbo
  fi

  # Turn off SMT
  if [ $(cat /sys/devices/system/cpu/smt/control) = "on" ]; then
    echo "Disabling SMT (Simultaneous Multithreading)..."
    echo off | sudo tee /sys/devices/system/cpu/smt/control
  fi
}

function build() {
  # Install necessary packages
  sudo apt update
  sudo apt install libnuma-dev libaio-dev

  cd "${SCRIPT_DIR}/.."
  mkdir -p build
  cd build
  cmake ..
  make -j$(nproc)
}

# Command line arguments
if [ "$1" == "hugepages" ]; then
  setup_hugepages
elif [ "$1" == "build" ]; then
  build
elif [ "$1" == "setup" ]; then
  system_setup
elif [ "$1" == "all" ]; then
  system_setup
  setup_hugepages
  build
else
  echo "Usage: $0 {setup | hugepages | build | all}"
  exit 1
fi

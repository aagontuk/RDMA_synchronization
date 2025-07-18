#!/bin/bash

########################################
# Installation script for Ubuntu 22.04 #
########################################

N_HUGE_PAGE=10240

n_huge=$(cat /proc/meminfo | grep -i HugePages_Total | awk '{print $2}')
s_huge=$(cat /proc/meminfo | grep -i Hugepagesize | awk '{print $2,$3}')

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

function build() {
  # Install necessary packages
  sudo apt update
  sudo apt install libnuma-dev libaio-dev

  mkdir build
  cd build
  cmake ..
  make -j$(nproc)
}

# Command line arguments
if [ "$1" == "hugepages" ]; then
  setup_hugepages
elif [ "$1" == "build" ]; then
  build
elif [ "$1" == "all" ]; then
  setup_hugepages
  build
else
  echo "Usage: $0 {hugepages | build | all}"
  exit 1
fi

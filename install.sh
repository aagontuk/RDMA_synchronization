#!/bin/bash

########################################
# Installation script for Ubuntu 22.04 #
########################################

N_HUGE_PAGE=10240

# Setup hugepages
# echo "${N_HUGE_PAGE}" | sudo tee /proc/sys/vm/nr_hugepages

# Install necessary packages
sudo apt update
sudo apt install libnuma-dev libaio-dev

mkdir build
cd build
cmake ..
make -j$(nproc)

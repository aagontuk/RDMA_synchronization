#!/bin/bash

########################################
# Installation script for Ubuntu 22.04 #
########################################

# Install necessary packages
sudo apt update
sudo apt install libnuma-dev libaio-dev

mkdir build
cd build
cmake ..
make -j$(nproc)

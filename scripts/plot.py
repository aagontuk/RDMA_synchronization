#!/usr/bin/env python3

# Script for plotting latency and tput graphs
# Usage: python plot_lat_tput.py <data_file>

import sys
import os
import pathlib
import pandas as pd
import matplotlib.pyplot as plt
import matplotlib.font_manager as font_manager
import matplotlib.ticker as ticker
import matplotlib as mpl
from math import log2, log10, ceil
import argparse

# Column width in latex template
LATEX_TEMPLATE_COLUMNWIDTH = 18

# Plot aspect ration
PLOT_ASPECT_RATIO = 16/6

# PLOT_WIDTH = LATEX_TEMPLATE_COLUMNWIDTH
# PLOT_HEIGHT = PLOT_WIDTH/PLOT_ASPECT_RATIO
PLOT_WIDTH = 3.38 # paper
# PLOT_WIDTH = 6
PLOT_HEIGHT = 2.5 # paper
# PLOT_HEIGHT = 6

SMALL_SIZE = 9
MEDIUM_SIZE = 10
BIGGER_SIZE = 12
# font = font_manager.FontProperties(family='Times New Roman', size=16)
# font = {'family' : 'Times New Roman', 'size'   : 10, 'weight' : 'normal'}
# mpl.rc('font', **font)
plt.rc('font', size=SMALL_SIZE)          # controls default text sizes
plt.rc('axes', titlesize=SMALL_SIZE)     # fontsize of the axes title
plt.rc('axes', labelsize=SMALL_SIZE)    # fontsize of the x and y labels
plt.rc('xtick', labelsize=SMALL_SIZE)    # fontsize of the tick labels
plt.rc('ytick', labelsize=SMALL_SIZE)    # fontsize of the tick labels
plt.rc('legend', fontsize=SMALL_SIZE)    # legend fontsize
plt.rc('figure', titlesize=BIGGER_SIZE)

X_COLUMN_SIZES='size'
X_LBL_SIZES='Object Size (B)'
X_COLUMN_THREADS='threads'
X_LBL_THREADS='Number of threads'
Y_COLUMN='throughput'
Y_LBL='Throughput (M GET/s)'

# LABELS = {"pessimistic_batch_32": "pessimistic_batch_32", "pessimistic_batch_1": "pessimistic", "broken_batch_1": "broken", "rc_batch_32": "rc_batch_32", "rcopt_batch_32": "rc_2QP_batch_32", "farm": "farm_broken", "farm_fixed_nomemcpy_batch_1": "farm_fixed", "farm_fixed_nomemcpy_batch_32": "farm_fixed_batch_32", "farm_fixed_memcpy_batch_1": "farm_fixed_memcpy", "farm_fixed_memcpy_batch_32": "farm_fixed_memcpy_batch_32", "broken_batch_32": "broken_batch_32"}
LABELS = {"pessimistic_batch_32": "Pessimistic", "farm_fixed_nomemcpy_batch_32": "Single Read", "farm_fixed_memcpy_batch_32": "FaRM", "broken_batch_32": "Cell"}
# COLORS = {"pessimistic_batch_32": "#984ea3", "pessimistic_batch_1": "#377eb8", "broken_batch_1": "#e41a1c", "rc_batch_32": "#ff7f00", "rcopt_batch_32": "#4daf4a", "farm": "#a65628", "farm_fixed_nomemcpy_batch_1": "#f781bf", "farm_fixed_nomemcpy_batch_32": "#6a3d9a", "farm_fixed_memcpy_batch_1": "#fdbf6f", "farm_fixed_memcpy_batch_32": "#cab2d6", "broken_batch_32": "#a6cee3"}
COLORS = {"pessimistic_batch_32": "#e41a1c", "farm_fixed_nomemcpy_batch_32": "#377eb8", "farm_fixed_memcpy_batch_32": "#4daf4a", "broken_batch_32": "#984ea3"}

MARKERS = {"pessimistic_batch_32": "x", "farm_fixed_nomemcpy_batch_32": "*", "farm_fixed_memcpy_batch_32": "p", "broken_batch_32": "o"}

def plot_sizes_vs_tput(df, machine, threads, out_dir):
    file_paths = []
    file_paths.append(os.path.join(out_dir, "sizes_vs_tput_m{}_t{}.pdf".format(machine, threads)))
    file_paths.append(os.path.join(out_dir, "sizes_vs_tput_m{}_t{}.png".format(machine, threads)))

    fig, ax = plt.subplots(figsize=(PLOT_WIDTH, PLOT_HEIGHT))

    # Find all the unique names from the 'bench' columns
    # bench_names = df['bench'].unique()
    bench_names = list(LABELS.keys())
    sizes = df['size'].unique()
    bench_names.sort()

    y_max = 0
    for name in bench_names:
        df_filtered = df[(df['bench'] == name) & (df['threads'] == threads)]
        df_filtered.plot(kind='line', ax=ax, x=X_COLUMN_SIZES, y=Y_COLUMN, marker=MARKERS[name], color=COLORS[name], label= LABELS[name])
        y_max = max(y_max, df_filtered[Y_COLUMN].max())

    plt.xlabel(X_LBL_SIZES)
    plt.ylabel(Y_LBL)
    # plt.title('Sizes vs Throughput for {} with {} threads'.format(machine, threads))


    ax.set_xscale('log', base=2)
    # plt.xticks(rotation=90)
    plt.xticks(ticks=sizes, labels=sizes)

    y_lim = y_max * 1.1
    # round
    y_lim = ceil(y_lim / 10) * 10

    ax.set_ylim(bottom=0, top=y_lim)
    ax.set_xlim(left=64)

    plt.legend(loc='lower center', bbox_to_anchor=(0.5, 0.98), ncol=len(LABELS.keys())/2)
    fig = plt.gcf()
    fig.tight_layout()
    for file in file_paths:
        fig.savefig(file, dpi=300)

def plot_threads_vs_tput(df, machine, size, out_dir):
    file_paths = []
    file_paths.append(os.path.join(out_dir, "threads_vs_tput_m{}_s{}.pdf".format(machine, size)))
    file_paths.append(os.path.join(out_dir, "threads_vs_tput_m{}_s{}.png".format(machine, size)))

    fig, ax = plt.subplots(figsize=(PLOT_WIDTH, PLOT_HEIGHT))

    # Find all the unique names from the 'bench' columns
    # bench_names = df['bench'].unique()
    bench_names = list(LABELS.keys())
    threads = df['threads'].unique()
    bench_names.sort()

    y_max = 0
    for name in bench_names:
        df_filtered = df[(df['bench'] == name) & (df['size'] == size)]
        df_filtered.plot(kind='line', ax=ax, x=X_COLUMN_THREADS, y=Y_COLUMN, marker=MARKERS[name], color=COLORS[name], label= LABELS[name])
        y_max = max(y_max, df_filtered[Y_COLUMN].max())

    plt.xlabel(X_LBL_THREADS)
    plt.ylabel(Y_LBL)
    # plt.title('Threads vs Throughput for {} with {} size'.format(machine, size))


    ax.set_xscale('log', base=2)
    # plt.xticks(rotation=90)
    plt.xticks(ticks=threads, labels=threads)

    y_lim = y_max * 1.1

    ax.set_ylim(bottom=0, top=y_lim)
    ax.set_xlim(left=threads.min())

    plt.legend(loc='lower center', bbox_to_anchor=(0.5, 1.06), ncol=len(LABELS.keys())/2)
    fig = plt.gcf()
    fig.tight_layout()
    for file in file_paths:
        fig.savefig(file, dpi=300)

def main():
    parser = argparse.ArgumentParser(description='Plot latency and throughput graphs.')
    parser.add_argument('data_file', type=str, help='Path to the data file containing latency and throughput data')
    parser.add_argument('--output_dir', type=str, default='.', help='Directory to save the output plots (default: current directory)')
    parser.add_argument('--machine', type=str, default='sm110p', help='CloudLab Machine name (default: sm110p)')
    parser.add_argument('--type', type=str, default='sizes', help='Plot type ["sizes", "threads"] (default: "sizes")')
    parser.add_argument('--threads', type=int, default=1, help='Number of threads to plot (default: 1)')
    parser.add_argument('--size', type=int, default=64, help='Size to plot (default: 64)')

    args = parser.parse_args()
    
    data_file = args.data_file
    output_dir = args.output_dir
    machine = args.machine
    plot_type = args.type
    threads = args.threads
    size = args.size

    df = pd.read_csv(data_file)

    if plot_type == 'sizes':
        print("Plotting sizes vs throughput for machine: {}, threads: {}".format(machine, threads))
        plot_sizes_vs_tput(df, machine, threads, output_dir)
    elif plot_type == 'threads':
        print("Plotting threads vs throughput for machine: {}, size: {}".format(machine, size))
        plot_threads_vs_tput(df, machine, size, output_dir)
    else:
        print("Invalid plot type. Use 'sizes' or 'threads'.")
        sys.exit(1)

if __name__ == '__main__':
    main()

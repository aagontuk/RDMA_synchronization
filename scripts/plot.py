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
# PLOT_WIDTH = 3.38 # paper
PLOT_WIDTH = 6
# PLOT_HEIGHT = 3 # paper
PLOT_HEIGHT = 4

SMALL_SIZE = 9
MEDIUM_SIZE = 10
BIGGER_SIZE = 12
# font = font_manager.FontProperties(family='Times New Roman', size=16)
# font = {'family' : 'Times New Roman', 'size'   : 10, 'weight' : 'normal'}
# mpl.rc('font', **font)
plt.rc('font', size=SMALL_SIZE)          # controls default text sizes
plt.rc('axes', titlesize=SMALL_SIZE)     # fontsize of the axes title
plt.rc('axes', labelsize=MEDIUM_SIZE)    # fontsize of the x and y labels
plt.rc('xtick', labelsize=SMALL_SIZE)    # fontsize of the tick labels
plt.rc('ytick', labelsize=SMALL_SIZE)    # fontsize of the tick labels
plt.rc('legend', fontsize=SMALL_SIZE)    # legend fontsize
plt.rc('figure', titlesize=BIGGER_SIZE)

X_COLUMN_SIZES='size'
X_LBL_SIZES='Sizes'
Y_COLUMN='throughput'
Y_LBL='Mop/s'
LABELS = {"pessimistic": "pessimistic_batch_32", "pessimistic_b1": "pessimistic", "broken": "broken", "rc": "rc_batch_32", "rcopt": "rc_2QP_batch_16"}
COLORS = {"pessimistic": "#984ea3", "pessimistic_b1": "#377eb8", "broken": "#e41a1c", "rc": "#ff7f00", "rcopt": "#4daf4a"}

def plot_sizes_vs_tput(df, machine, threads, out_dir):
    file_paths = []
    file_paths.append(os.path.join(out_dir, "sizes_vs_tput_m{}_t{}.pdf".format(machine, threads)))
    file_paths.append(os.path.join(out_dir, "sizes_vs_tput_m{}_t{}.png".format(machine, threads)))

    fig, ax = plt.subplots(figsize=(PLOT_WIDTH, PLOT_HEIGHT))

    # Find all the unique names from the 'bench' columns
    bench_names = df['bench'].unique()
    sizes = df['size'].unique()

    y_max = 0
    for name in bench_names:
        df_filtered = df[(df['bench'] == name) & (df['threads'] == threads)]
        df_filtered.plot(kind='line', ax=ax, x=X_COLUMN_SIZES, y=Y_COLUMN, marker='o', color=COLORS[name], label= LABELS[name])
        y_max = max(y_max, df_filtered[Y_COLUMN].max())

    plt.xlabel(X_LBL_SIZES)
    plt.ylabel(Y_LBL)
    plt.title('Throughput vs Sizes for {} with {} threads'.format(machine, threads))


    ax.set_xscale('log', base=2)
    plt.xticks(rotation=90)
    plt.xticks(ticks=sizes, labels=sizes)

    y_lim = y_max * 1.1

    ax.set_ylim(bottom=0, top=y_lim)
    ax.set_xlim(left=64)

    fig = plt.gcf()
    fig.tight_layout()
    for file in file_paths:
        fig.savefig(file, dpi=300)

def main():
    parser = argparse.ArgumentParser(description='Plot latency and throughput graphs.')
    parser.add_argument('data_file', type=str, help='Path to the data file containing latency and throughput data')
    parser.add_argument('--output_dir', type=str, default='.', help='Directory to save the output plots (default: current directory)')
    parser.add_argument('--machine', type=str, default='sm110p', help='CloudLab Machine name (default: sm110p)')
    parser.add_argument('--threads', type=int, default=1, help='Number of threads to plot (default: 1)')

    args = parser.parse_args()
    
    data_file = args.data_file
    output_dir = args.output_dir
    machine = args.machine
    threads = args.threads

    df = pd.read_csv(data_file)

    plot_sizes_vs_tput(df, machine, threads, output_dir)

if __name__ == '__main__':
    main()

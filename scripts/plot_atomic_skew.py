#!/usr/bin/env python3

# Script for plotting atomic HCA vs Global throughput across zipf skew
# Usage: python plot_atomic_skew.py --hca <hca_csv> --glob <glob_csv>
# Either --hca or --glob may be omitted to plot only the other one.

import sys
import os
import pandas as pd
import matplotlib.pyplot as plt
import matplotlib as mpl
from math import ceil
import argparse

# Plot size (paper column width style, wide enough for 4 subplots)
PLOT_WIDTH = 7.0
PLOT_HEIGHT = 4.2

SMALL_SIZE = 9
MEDIUM_SIZE = 10
BIGGER_SIZE = 12
plt.rc('font', size=SMALL_SIZE)          # controls default text sizes
plt.rc('axes', titlesize=SMALL_SIZE)     # fontsize of the axes title
plt.rc('axes', labelsize=SMALL_SIZE)     # fontsize of the x and y labels
plt.rc('xtick', labelsize=SMALL_SIZE)    # fontsize of the tick labels
plt.rc('ytick', labelsize=SMALL_SIZE)    # fontsize of the tick labels
plt.rc('legend', fontsize=SMALL_SIZE)    # legend fontsize
plt.rc('figure', titlesize=BIGGER_SIZE)

X_COLUMN = 'zipf'
X_LBL = 'Zipf skew'
Y_COLUMN = 'throughput_mops'
Y_LBL = 'Throughput (Mop/s)'

# read_pct values present in the data -> subplot title
WORKLOADS = [100, 95, 50, 0]
WORKLOAD_TITLES = {100: 'Read-Only (100% GET)', 95: 'Read-Heavy (95% GET)', 50: 'Balanced (50% GET)', 0: 'Write-Only (0% GET)'}

LABELS = {"hca": "HCA", "hca_pad": "HCA + padding", "glob": "Global", "glob_pad": "Global + padding"}
COLORS = {"hca": "#e41a1c", "hca_pad": "#377eb8", "glob": "#4daf4a", "glob_pad": "#984ea3"}
MARKERS = {"hca": "x", "hca_pad": "*", "glob": "p", "glob_pad": "o"}
SERIES = ["hca", "hca_pad", "glob", "glob_pad"]

def load_data(hca_file=None, glob_file=None):
    frames = {}

    if hca_file:
        df_hca = pd.read_csv(hca_file)
        df_hca['throughput_mops'] = df_hca['aggregate_throughput_tx_per_sec'] / 1e6
        frames["hca"] = df_hca[df_hca['padding'] == 0]
        frames["hca_pad"] = df_hca[df_hca['padding'] != 0]

    if glob_file:
        df_glob = pd.read_csv(glob_file)
        df_glob['throughput_mops'] = df_glob['aggregate_throughput_tx_per_sec'] / 1e6
        frames["glob"] = df_glob[df_glob['padding'] == 0]
        frames["glob_pad"] = df_glob[df_glob['padding'] != 0]

    return frames

def plot_atomic_skew(frames, out_dir):
    series = [name for name in SERIES if name in frames]

    file_paths = []
    file_paths.append(os.path.join(out_dir, "atomic_skew.pdf"))
    file_paths.append(os.path.join(out_dir, "atomic_skew.png"))

    fig, axes = plt.subplots(2, 2, figsize=(PLOT_WIDTH, PLOT_HEIGHT), sharex=True, sharey=True)
    axes = axes.flatten()

    zipf_values = sorted(frames[series[0]][X_COLUMN].unique())
    x_ticks = list(range(len(zipf_values)))
    zipf_to_x = {z: i for i, z in enumerate(zipf_values)}

    y_max = 0
    for ax, read_pct in zip(axes, WORKLOADS):
        for name in series:
            df_filtered = frames[name][frames[name]['read_pct'] == read_pct].sort_values(X_COLUMN)
            xs = [zipf_to_x[z] for z in df_filtered[X_COLUMN]]
            ax.plot(xs, df_filtered[Y_COLUMN], marker=MARKERS[name], color=COLORS[name], label=LABELS[name])
            y_max = max(y_max, df_filtered[Y_COLUMN].max())

        ax.set_title(WORKLOAD_TITLES[read_pct])
        ax.set_xticks(x_ticks)
        ax.set_xticklabels([str(z) for z in zipf_values])

    y_lim = ceil((y_max * 1.1) / 5) * 5
    for ax in axes:
        ax.set_ylim(bottom=0, top=y_lim)
        ax.set_xlim(left=x_ticks[0], right=x_ticks[-1])

    fig.text(0.5, 0.0, X_LBL, ha='center')
    fig.text(0.0, 0.5, Y_LBL, va='center', rotation='vertical')

    handles, labels = axes[0].get_legend_handles_labels()
    fig.legend(handles, labels, loc='lower center', bbox_to_anchor=(0.5, 1.0), ncol=len(series))

    fig.tight_layout()
    for file in file_paths:
        fig.savefig(file, dpi=300, bbox_inches='tight')

def main():
    parser = argparse.ArgumentParser(description='Plot HCA vs Global atomic throughput across zipf skew.')
    parser.add_argument('--hca', dest='hca_file', type=str, default=None, help='Path to the HCA atomic results CSV')
    parser.add_argument('--glob', dest='glob_file', type=str, default=None, help='Path to the Global atomic results CSV')

    args = parser.parse_args()

    if not args.hca_file and not args.glob_file:
        parser.error('At least one of --hca or --glob must be provided')

    frames = load_data(args.hca_file, args.glob_file)
    out_dir = os.path.dirname(os.path.abspath(args.hca_file or args.glob_file))
    plot_atomic_skew(frames, out_dir)
    print("Saved plots to {}".format(out_dir))

if __name__ == '__main__':
    main()

#!/usr/bin/env python

import sys

import numpy as np

from common.exp import get_data, format_bps

from matplotlib import pyplot as plt

MARKERS = '>^+*'

data = get_data(sys.argv[1])
data.sort(key=lambda row: row['connections'])

keys = list({(row['tx'], row['rx']) for row in data})
x_connections = {}
y_bps = {}
y_pps = {}

for key in keys:
    x_connections[key] = np.array([row['connections'] for row in data if (row['tx'], row['rx']) == key])
    y_pps[key] = np.array([row['pps'] for row in data if (row['tx'], row['rx']) == key])
    y_bps[key] = np.array([row['bps'] for row in data if (row['tx'], row['rx']) == key])

f = open('exp2-mean-bps.tex', 'wt')

plt.figure(figsize=[14, 8])
plt.title('MEAN total goodput by number of connections')
plt.xlabel('connections')
plt.ylabel('bps')

marker = 0

f.write('''
\\begin{center}
\\begin{tabular}{ c c c c c c }
\\multicolumn{6}{c}{MEAN total goodput(b/s) by number of connections} \\\\
\\hline
''')

f.write(f'tx & rx & ' + ' & '.join(f'{c} con' for c in x_connections[key]) + ' \\\\\n')

for key in keys:
    if (len(x_connections[key]) == 0) or (len(y_bps[key]) == 0):
        continue

    tx, rx = key

    f.write(f'{tx} & {rx} & ' + ' & '.join(f'{format_bps(c)}' for c in y_bps[key]) + ' \\\\\n')

    plt.plot(x_connections[key], y_bps[key], label=key, marker=MARKERS[marker])
    marker = (marker + 1) % len(MARKERS)

plt.legend()
plt.savefig(f'exp2-mean-bps.png')
plt.show()

f.write('''
\\end{tabular}
\\end{center}
''')
f.close()

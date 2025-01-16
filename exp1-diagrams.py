#!/usr/bin/env python

import sys

import numpy as np

from common.exp import get_data, format_bps

from matplotlib import pyplot as plt

MARKERS = '>^+*'

data = get_data(sys.argv[1])
data.sort(key=lambda row: row['mss'])

keys = list({(row['tx'], row['rx']) for row in data})
x_mss = {}
y_bps = {}
y_pps = {}

for key in keys:
    x_mss[key] = np.array([row['mss'] for row in data if (row['tx'], row['rx']) == key])
    y_pps[key] = np.array([row['pps'] for row in data if (row['tx'], row['rx']) == key])
    y_bps[key] = np.array([row['bps'] for row in data if (row['tx'], row['rx']) == key])

f = open('exp1-mean-bps.tex', 'wt')

plt.figure(figsize=[14, 8])
plt.title('MEAN goodput by segment size')
plt.xlabel('mss')
plt.ylabel('bps')

marker = 0

f.write('''
\\begin{center}
\\begin{tabular}{ c c c c c c }
\\multicolumn{6}{c}{MEAN goodput(b/s) by segment size} \\\\
\\hline
''')

f.write(f'tx & rx & ' + ' & '.join(f'MSS {c}B' for c in x_mss) + ' \\\\\n')

for key in keys:
    if (len(x_mss[key]) == 0) or (len(y_bps[key]) == 0):
        continue

    tx, rx = key

    f.write(f'{tx} & {rx} & ' + ' & '.join(f'{format_bps(c)}' for c in y_bps[key]) + ' \\\\\n')

    plt.plot(x_mss[key], y_bps[key], label=key, marker=MARKERS[marker])
    marker = (marker + 1) % len(MARKERS)

plt.legend()
plt.savefig(f'exp1-mean-bps.png')
plt.show()

f.write('''
\\end{tabular}
\\end{center}
''')
f.close()

f = open('exp1-mean-pps.tex', 'wt')

plt.figure(figsize=[14, 8])
plt.title('MEAN packet-rate by segment size')
plt.xlabel('mss')
plt.ylabel('pps')

marker = 0

f.write('''
\\begin{center}
\\begin{tabular}{ c c c c c c }
\\multicolumn{6}{c}{MEAN packet-rate(p/s) by segment size} \\\\
\\hline
''')

f.write(f'tx & rx & ' + ' & '.join(f'MSS {c}B' for c in x_mss) + ' \\\\\n')

for key in keys:
    if (len(x_mss[key]) == 0) or (len(y_pps[key]) == 0):
        continue

    tx, rx = key

    f.write(f'{tx} & {rx} & ' + ' & '.join(f'{c}' for c in y_pps[key]) + ' \\\\\n')

    plt.plot(x_mss[key], y_pps[key], label=key, marker=MARKERS[marker])
    marker = (marker + 1) % len(MARKERS)

plt.legend()
plt.savefig(f'exp1-mean-pps.png')
plt.show()

f.write('''
\\end{tabular}
\\end{center}
''')
f.close()

import glob
import os

MARKERS = '>^+*'

def get_data(dentry):
    data = []
    for fname in glob.glob(f'{dentry}/h2.*.log'):
        with open(fname) as f:
            fname = os.path.basename(fname).split('.')

            tx, rx = fname[1].split('-')
            tx = tx.replace('ndpip', 'SlimTCP')
            rx = rx.replace('ndpip', 'SlimTCP')
            tx = tx.replace('f_stack', 'f-stack')
            rx = rx.replace('f_stack', 'f-stack')

            mss = int(fname[3])
            connections = int(fname[4])

            lines = [line.strip().split(' ') for line in f if 'bps=' in line]
            lines = [{
                'pps': int(line[0][4:][:-1]),
                'bps': int(line[1][4:][:-1]),
                'connections': int(line[2][12:][:-1])
            } for line in lines]

            lines = [line for line in lines if line['connections'] == connections]
            if len(lines) == 0:
                lines = [{'pps': 0, 'bps': 0, 'connections': connections}]

            elif len(lines) == 1:
                pass

            else:
                lines = lines[1:]

            pps = sum(line['pps'] for line in lines) // len(lines)
            bps = sum(line['bps'] for line in lines) // len(lines)

            data.append({
                'tx': tx,
                'rx': rx,
                'mss': mss,
                'connections': connections,
                'pps': pps,
                'bps': bps
            })

    return data

def format_bps(bps):
    if bps < 10**3:
        return f'{bps / 10**0:.1f}'

    elif bps < 10**6:
        return f'{bps / 10**3:.1f}K'

    elif bps < 10**9:
        return f'{bps / 10**6:.1f}M'

    elif bps < 10**12:
        return f'{bps / 10**9:.1f}G'

    else:
        return ''

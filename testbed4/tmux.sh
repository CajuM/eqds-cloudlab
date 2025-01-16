#!/bin/sh

set -ex

TOP=$(dirname $(dirname $(readlink -f $0)))

. /tmp/devshell

case $1 in
	self)
		tmux \
			new-session -d \; \
			new-window -d "./tmux.sh testpmd" \; \
			new-window -d "./tmux.sh vm 1" \; \
			new-window -d "./tmux.sh vm 2" \; \
			new-window -d "./tmux.sh affinity"
		;;

	testpmd)
		${TOP}/testbed1/testpmd.sh
		;;

	vm)
		shift
		vm=$1

		export TMPDIR=/tmp/run-nixos-vm${vm}-tmp

		rm -rf ${TMPDIR}
		mkdir -p ${TMPDIR}
		cd ${TMPDIR}

		while ! /tmp/run-nixos-vm${vm} &>/tmp/run-nixos-vm${vm}.log; do
			rm -rf ${TMPDIR}
			mkdir -p ${TMPDIR}
			cd ${TMPDIR}
		done
		;;

	affinity)
		while ! qemu-affinity -k 3 4 -- $(pgrep -f "qemu.*dpdk1" | head -n2 | tail -n1); do :; done
		while ! qemu-affinity -k 5 6 -- $(pgrep -f "qemu.*dpdk2" | head -n2 | tail -n1); do :; done
		;;
esac

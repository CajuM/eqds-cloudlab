#!/bin/sh

set -ex

TOP=$(dirname $(dirname $(readlink -f $0)))

. /tmp/devshell

case $1 in
	self)
		shift
		me=$1
		env=$2

		tmux \
			new-session -d \; \
			new-window -d "./tmux.sh eqdsshim ${me} ${env}" \; \
			new-window -d "./tmux.sh vm ${me}" \; \
			new-window -d "./tmux.sh affinity"
		;;

	eqdsshim)
		shift
		me=$1
		env=$2

		${TOP}/testbed2/eqdsshim.sh ${me} "${env}"
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
		while ! qemu-affinity -k 3 4 -- $(pgrep -f "qemu.*dpdk" | head -n2 | tail -n1); do :; done
		;;
esac

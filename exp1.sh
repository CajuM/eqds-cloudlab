#!/bin/sh

set -ex

exp="exp1"

options=$(getopt -l "short,reboot,connections:,stacks-tx:,stacks-rx:,testbed-tx:,testbed-rx:,env:" -o "sx" -- "$@")
eval set -- "$options"

tcp_mss_list='64 256 512 1460'
connections=1
reboot=0
excludes=""

while true; do
	case "$1" in
		--connections) connections=$2 shift; shift;;
		--reboot) reboot=1; shift;;
		--stacks-tx) stacks_tx=$2; shift; shift;;
		--stacks-rx) stacks_rx=$2; shift; shift;;
		--testbed-tx) testbed_tx=$2; shift; shift;;
		--testbed-rx) testbed_rx=$2; shift; shift;;
		--env) env=$2; shift; shift;;
		--) shift; break;;
	esac
done

TOP=$(dirname $(readlink -f $0))

. "${TOP}/common/head.sh"

setup_exp

set +e

for mss in $(eval "echo $tcp_mss_list"); do
	if [[ $short == 1 && $mss -gt 640 ]]; then
		break
	fi

	do_exp "tcp" ${mss} ${connections}
done

kill_exp

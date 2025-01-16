#!/bin/sh

set -ex

exp="exp1"

options=$(getopt -l "short,reboot,connections:,stacks-h1:,stacks-h2:,testbed-h1:,testbed-h2:,env:" -o "sx" -- "$@")
eval set -- "$options"

tcp_mss_list='64 256 512 1460'
connections=1
reboot=0
excludes=""

while true; do
	case "$1" in
		--connections) connections=$2 shift; shift;;
		--reboot) reboot=1; shift;;
		--stacks-h1) stacks_h1=$2; shift; shift;;
		--stacks-h2) stacks_h2=$2; shift; shift;;
		--testbed-h1) testbed_h1=$2; shift; shift;;
		--testbed-h2) testbed_h2=$2; shift; shift;;
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

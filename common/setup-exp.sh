#!/bin/sh

set -ex

TOP=$(dirname $(dirname $(readlink -f $0)))
FLAKE="${TOP}?submodules=1"

options=$(getopt -l "reboot,testbed-tx:,testbed-rx:,env:" -o "sx" -- "$@")
eval set -- "$options"

reboot=0

while true; do
	case "$1" in
		--reboot) reboot=1; shift;;
		--testbed-tx) testbed_tx=$2; shift; shift;;
		--testbed-rx) testbed_rx=$2; shift; shift;;
		--env) env=$2; shift; shift;;
		--host) host=$2; shift; shift;;
		--) shift; break;;
	esac
done

. "${TOP}/common/head.sh"

function setup_host() {
	host_n=$1
	reboot=$2
	testbed=$3

	host=$(eval "echo \${HOST${host_n}}")
	machine=$(eval "echo \${HOST${host_n}_MACHINE}")

	while ! ssh ${host} true; do :; done
	tar --exclude .git -C ${TOP}/.. -cz $(basename $TOP) | ssh ${host} tar xvz

	nix copy -s --to ssh://${host} "${FLAKE}#${machine}.exp-shell"
	devshell=$(nix build --no-link --print-out-paths "${FLAKE}#${machine}.exp-shell")
	cat ${devshell} | grep -P '^declare -x PATH=' | sed 's/declare -x/export/g' | ssh ${host} 'cat >/tmp/devshell'

	ssh ${host} ./eqds-cloudlab/${testbed}/setup-run.sh ${host_n} ${env}
}

cd "${TOP}"

while ! ssh ${HOST1} true; do :; done
if [ $N_HOSTS == 2 ]; then while ! ssh ${HOST2} true; do :; done; fi

kill_exp

setup_host 1 ${reboot} ${testbed_tx} &
if [ $N_HOSTS == 2 ]; then setup_host 2 ${reboot} ${testbed_rx} & fi

while ! $SSH1 true; do :; done
while ! $SSH2 true; do :; done

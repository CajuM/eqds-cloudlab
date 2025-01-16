function setup_exp {
	rm -rf "${LOGS}"
	mkdir -p "${LOGS}"

	extra_args=""

	if [ -n "${testbed_h2}" ]; then
		extra_args="${extra_args} --testbed-h2 ${testbed_h2}"
	fi

	if [ "${reboot}" == "1" ]; then
		extra_args="${extra_args} --reboot"
	fi

	${TOP}/common/setup-exp.sh --env ${env} --testbed-h1 ${testbed_h1} ${extra_args}
}

function kill_exp {
	extra_args=""

	if [ -n "${testbed_h2}" ]; then
		extra_args="${extra_args} --testbed-h2 ${testbed_h2}"
	fi

	if [ "${reboot}" == "1" ]; then
		extra_args="${extra_args} --reboot"
	fi

	${TOP}/common/kill-exp.sh --env ${env} --testbed-h1 ${testbed_h1} ${extra_args}
}

function mtcp_tcp {
	host=$1
	mss=$2
	connections=$3
	log=$4

	peer=$((1 + (host % 2)))

	eval "echo \${SSH${host}} MTCP_MSS=${mss} MTCP_CONFIG=perf.conf stdbuf -o0 mtcp-kiss --timeout 20 --connect-ip 10.1.1.${peer} --connections ${connections}"
}

function f_stack_tcp {
	host=$1
	mss=$2
	connections=$3
	log=$4

	peer=$((1 + (host % 2)))

	cat "${TOP}/common/f-stack-config.ini.in" | NO_HW_CKSUM=$(eval "echo \$(((NODE${host}_HAS_HW_CKSUM + 1) % 2))") MSS=${mss} HOST_PCI=$(eval "echo \${NODE${host}_PCI}") IP_ADDR="10.1.1.${host}" envsubst | eval "\${SSH${host}} 'cat >/tmp/f-stack-config.ini'"
	eval "echo \${SSH${host}} stdbuf -o0 f-stack-kiss --conf /tmp/f-stack-config.ini --proc-type=primary --proc-id=0 -- --timeout 20 --arp 10.1.1.${peer}:\${NODE${peer}_MAC} --connect-ip 10.1.1.${peer} --connections ${connections} --mss ${mss} --tcp"
}

function ndpip_tcp {
	host=$1
	mss=$2
	connections=$3
	log=$4

	peer=$((1 + (host % 2)))

	eval "echo \${SSH${host}} stdbuf -o0 libndpip-kiss --no-telemetry -a \${NODE${host}_PCI} -l 0,1 --proc-type=primary --socket-mem=2048 -- --timeout 20 --iface 0 --burst 32 --arp 10.1.1.${peer}:\${NODE${peer}_MAC} --bind-eth \${NODE${host}_MAC} --bind-ip 10.1.1.${host} --connections ${connections} --connect-ip 10.1.1.${peer} --mss ${mss} --tcp"
}

function linux_tcp {
	host=$1
	mss=$2
	connections=$3
	log=$4

	peer=$((1 + (host % 2)))

	eval "\${SSH${host}} taskset -a 0,1 stdbuf -o0 linux-kiss --timeout 20 --iface \${NODE${host}_IFACE} --connect-ip 10.1.1.${peer} --connect-port 4112 --connections ${connections} --mss ${mss}"
}

function do_exp {
	proto=$1
	mss=$2
	connections=$3

	if [ "${proto}" == "tcp" ]; then
		payload_inc=20
	fi

	for s1 in ${stacks_h1}; do
		for s2 in ${stacks_h2}; do
			for _ in $(seq 1 5); do
				host1_log="${LOGS}/h1.${s1}-${s2}.${proto}.${mss}.${connections}.log"
				host1_cmd=$(eval "${s1}_${proto} 1 $mss $connections")
				${host1_cmd} &>"${host1_log}" &
				host1_pid=$!

				host2_log="${LOGS}/h2.${s1}-${s2}.${proto}.${mss}.${connections}.log"
				host2_cmd=$(eval "${s2}_${proto} 2 $mss $connections")
				${host2_cmd} &>"${host2_log}" &
				host2_pid=$!

				wait $host1_pid
				wait $host2_pid

				if (grep -v '^pps=0;' "${host1_log}" | grep -P '^pps=') && \
					(grep -v '^pps=0;' "${host2_log}" | grep -P '^pps='); then

					break
				fi
			done
		done
	done
}

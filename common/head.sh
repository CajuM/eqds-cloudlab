. "${TOP}/${env}"

. "$(readlink -f ${testbed_h1})/vars.sh"
TMP_NODE1_HAS_HW_CKSUM=${NODE1_HAS_HW_CKSUM}
TMP_NODE1_MAC=${NODE1_MAC}
TMP_NODE1_PCI=${NODE1_PCI}
TMP_SSH1=${SSH1}

if [ -n "${testbed_h2}" ]; then
	. "$(readlink -f ${testbed_h2})/vars.sh"
	NODE2_HAS_HW_CKSUM=${NODE1_HAS_HW_CKSUM}
	NODE2_MAC=${NODE1_MAC}
	NODE2_PCI=${NODE1_PCI}
	SSH2=${SSH1}
fi

NODE1_HAS_HW_CKSUM=${TMP_NODE1_HAS_HW_CKSUM}
NODE1_MAC=${TMP_NODE1_MAC}
NODE1_PCI=${TMP_NODE1_PCI}
SSH1=${TMP_SSH1}

. "${TOP}/common/funcs.sh"

if [ -n "${testbed_h2}" ]; then
	LOGS="${TOP}/out/${ENV_NAME}-${testbed_h1}_${testbed_h2}-${exp}/logs"
else
	LOGS="${TOP}/out/${ENV_NAME}-${testbed_h1}-${exp}/logs"
fi

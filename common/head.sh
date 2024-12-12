. "${TOP}/${env}"

. "$(readlink -f ${testbed_tx})/vars.sh"
TMP_NODE1_PCI=${NODE1_PCI}
TMP_NODE1_MAC=${NODE1_MAC}
TMP_NODE1_HAS_HW_CKSUM=${NODE1_HAS_HW_CKSUM}
TMP_SSH1=${SSH1}

. "$(readlink -f ${testbed_rx})/vars.sh"
NODE1_PCI=${TMP_NODE1_PCI}
NODE1_MAC=${TMP_NODE1_MAC}
NODE1_HAS_HW_CKSUM=${TMP_NODE1_HAS_HW_CKSUM}
SSH1=${TMP_SSH1}

. "${TOP}/common/funcs.sh"

LOGS="${TOP}/out/${ENV_NAME}-${testbed_tx}_${testbed_rx}-${exp}/logs"

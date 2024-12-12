N_HOSTS=1

NODE1_PCI=0000:00:10.0
NODE2_PCI=0000:00:10.0

NODE1_MAC=12:23:34:45:56:01
NODE2_MAC=12:23:34:45:56:02

SSH1="ssh -J ${HOST1} -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null root@10.2.1.1"
SSH2="ssh -J ${HOST1} -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null root@10.2.2.1"

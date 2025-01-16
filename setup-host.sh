#!/bin/sh

set  -ex

if [ -f /var/setup-host ]; then
	exit 0
fi

export DEBIAN_FRONTEND=noninteractive

apt-get update
apt-get -y dist-upgrade
apt-get -y install curl sudo xz-utils

curl -Lo /tmp/install https://nixos.org/nix/install
chmod a+x /tmp/install
/tmp/install --daemon --yes --nix-extra-conf-file ${TOP}/common/nix.conf
ln -sf $HOME/.nix-profile/bin/* /usr/bin/

(
    . /etc/default/grub
    GRUB_CMDLINE_LINUX_DEFAULT="${GRUB_CMDLINE_LINUX_DEFAULT} isolcpus=1-5 nohz_full=1-5 rcu_nocbs=1-5 amd_iommu=on iommu=pt default_hugepagesz=1G hugepagesz=1G hugepages=8 processor.max_cstate=0 rcu_nocb_poll audit=0"
    sed -i "s@GRUB_CMDLINE_LINUX_DEFAULT.*@GRUB_CMDLINE_LINUX_DEFAULT=\"${GRUB_CMDLINE_LINUX_DEFAULT}\"@g" /etc/default/grub
)
update-grub

touch /var/setup-host

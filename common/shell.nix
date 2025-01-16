{ pkgs, ... }:

pkgs.mkShell {
  packages = with pkgs; [
    dpdk
    ethtool
    gdb
    gettext
    iproute2
    kmod
    pciutils
    procps
    systemd
    tmux
    which
    dpdk-iface
    qemu-affinity
    libndpip-kiss
    mtcp-kiss
    f-stack-kiss
    linux-kiss
  ];
}

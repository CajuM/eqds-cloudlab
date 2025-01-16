{ pkgs, ... }:

pkgs.mkShell {
  packages = with pkgs; [
    dpdk
    ethtool
    gdb
    gettext
    kmod
    iproute2
    pciutils
    procps
    systemd
    tmux
    which
    dpdk-iface
    qemu-affinity
    libndpip-perf
    mtcp-perf
    f-stack-perf
    linux-perf
  ];
}

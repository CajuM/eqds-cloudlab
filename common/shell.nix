{ pkgs, ... }:

pkgs.mkShell {
  packages = with pkgs; [
    dpdk
    gdb
    gettext
    kmod
    iproute2
    procps
    tmux
    which
    dpdk-iface
    qemu-affinity
    eqds-tcp-perf
    mtcp-perf
    f-stack-perf
    linux-perf
  ];
}

(
  self: super:
  let
    stdenv = self.myStdenv;
    dpdk = self.dpdk;

    dbgStdenv = self.dbgStdenv;

  in
  rec {
    libndpip = self.callPackage ../pkgs/libndpip {
      #stdenv = dbgStdenv;
      stdenv = stdenv;
      dpdk = dpdk;
    };
    libndpip-perf = self.callPackage ../pkgs/libndpip-perf {
      inherit libndpip;
      #stdenv = dbgStdenv;
      stdenv = stdenv;
      dpdk = libndpip.dpdk;
    };

    f-stack = self.callPackage ../pkgs/f-stack { inherit stdenv; };
    f-stack-perf = self.callPackage ../pkgs/f-stack-perf {
      inherit stdenv f-stack;
      dpdk = f-stack.dpdk;
    };

    mtcp = self.callPackage ../pkgs/mtcp { inherit stdenv; };
    dpdk-iface = self.callPackage ../pkgs/dpdk-iface {
      inherit stdenv;
      dpdk = mtcp.dpdk;
    };
    dpdk-iface-kmod-vm = self.callPackage ../pkgs/dpdk-iface/kmod.nix {
      kernel = self.myLinuxPackages.kernel;
    };
    mtcp-perf = self.callPackage ../pkgs/mtcp-perf {
      inherit stdenv mtcp;
      dpdk = mtcp.dpdk;
    };

    linux-perf = self.callPackage ../pkgs/linux-perf {
      inherit stdenv;
    };

    qemu-affinity = self.callPackage ../pkgs/qemu-affinity { };
  }
)

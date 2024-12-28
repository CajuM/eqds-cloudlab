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
    libndpip-kiss = self.callPackage ../pkgs/libndpip-kiss {
      inherit libndpip;
      #stdenv = dbgStdenv;
      stdenv = stdenv;
      dpdk = libndpip.dpdk;
    };

    libndpip-perf = self.callPackage ../pkgs/libndpip-perf {
      #stdenv = dbgStdenv;
      stdenv = stdenv;
      dpdk = dpdk;
    };
    libndpip-perf-kiss' = self.callPackage ../pkgs/libndpip-kiss {
      #stdenv = dbgStdenv;
      stdenv = stdenv;
      dpdk = libndpip.dpdk;
      libndpip = libndpip-perf;
    };
    libndpip-perf-kiss = self.runCommand "copy" { } ''
      mkdir -p $out/bin
      cp ${libndpip-perf-kiss'}/bin/libndpip-kiss $out/bin/
    '';

    f-stack = self.callPackage ../pkgs/f-stack { inherit stdenv; };
    f-stack-kiss = self.callPackage ../pkgs/f-stack-kiss {
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
    mtcp-kiss = self.callPackage ../pkgs/mtcp-kiss {
      inherit stdenv mtcp;
      dpdk = mtcp.dpdk;
    };

    linux-kiss = self.callPackage ../pkgs/linux-kiss {
      inherit stdenv;
    };

    qemu-affinity = self.callPackage ../pkgs/qemu-affinity { };
  }
)

{ stdenv
, lib
, kernel
}:

stdenv.mkDerivation {
  pname = "dpdk-iface-kmod";
  version = "0";
  src = ./.;

  buildPhase = ''
    make -C ${kernel.dev}/lib/modules/*/build M=$PWD EXTRA_CFLAGS= modules
  '';

  installPhase = ''
    mkdir -p $out
    cp dpdk_iface.ko $out/
  '';
}

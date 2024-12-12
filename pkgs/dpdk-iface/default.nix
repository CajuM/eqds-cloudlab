{ stdenv
, lib
, makeWrapper
, elfutils
, pkg-config
, dpdk
, jansson
, libmnl
, libnl
, libpcap
, numactl
, openssl
, rdma-core
, zlib
}:

stdenv.mkDerivation rec {
  pname = "dpdk-iface";
  version = "0";
  src = ./.;

  nativeBuildInputs = [
    elfutils
    makeWrapper
    pkg-config
  ];

  buildInputs = [
    dpdk
    jansson
    libmnl
    libnl
    libpcap
    numactl
    openssl
    rdma-core
    zlib
  ];

  makeFlags = [
    "-f Makefile.app"
    "RTE_SDK=${dpdk}/share/dpdk"
    "RTE_TARGET=x86_64-native-linuxapp-gcc"
  ];

  dontStrip = true;

  enableParallelBuilding = true;

  installPhase = ''
    mkdir -p $out/bin $out/lib/modules
    cp build/dpdk_iface_main $out/bin
    wrapProgram $out/bin/dpdk_iface_main \
      --set LD_LIBRARY_PATH ${lib.makeLibraryPath [ dpdk ]}
  '';
}

{ stdenv
, lib
, pkg-config
, jansson
, libelf
, libnl
, libpcap
, numactl
, openssl
, zlib
, dpdk
, lib-ndpip
, ndpipGrantsEnable
}:

stdenv.mkDerivation {
  name = "eqds-tcp-perf";

  src = ./src;

  dontStrip = true;

  nativeBuildInputs = [ pkg-config ];

  buildInputs = [
    jansson
    libelf
    libnl
    libpcap
    numactl
    openssl
    zlib
    dpdk
    lib-ndpip
  ];

  CFLAGS = lib.concatStringsSep " " (
    (lib.optional ndpipGrantsEnable "-DNDPIP_GRANTS_ENABLE")
  );

  installPhase = ''
    mkdir -p $out/bin
    cp eqds-tcp-perf $out/bin
  '';
}

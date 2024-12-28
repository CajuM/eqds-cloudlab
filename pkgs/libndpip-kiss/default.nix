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
, libndpip
, ndpipGrantsEnable
}:

stdenv.mkDerivation {
  name = "libndpip-kiss";

  src = ./.;

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
    libndpip
  ];

  CFLAGS = lib.concatStringsSep " " (
    (lib.optional ndpipGrantsEnable "-DNDPIP_GRANTS_ENABLE")
  );

  installPhase = ''
    mkdir -p $out/bin
    cp libndpip-kiss $out/bin
  '';
}

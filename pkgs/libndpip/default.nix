{ pkgs
, lib
, stdenv
, dpdk
, libbsd
, pkg-config
, disableTxHwCksum
, disableRxCksum
, ndpipGrantsEnable
}:

stdenv.mkDerivation {
  name = "libndpip";

  src = ./src;

  passthru = {
    inherit dpdk;
  };

  nativeBuildInputs = [ pkg-config ];
  buildInputs = [
    dpdk
    libbsd
  ];

  dontStrip = true;

  CFLAGS = lib.concatStringsSep " " (
    (lib.optional disableTxHwCksum "-DNDPIP_DEBUG_NO_TX_HW_CKSUM") ++
    (lib.optional disableRxCksum "-DNDPIP_DEBUG_NO_RX_CKSUM") ++
    (lib.optional ndpipGrantsEnable "-DNDPIP_GRANTS_ENABLE")
  );

  enableParallelBuilding = true;

  PREFIX = "$(out)";
  makefile = "Makefile.linux-dpdk";

  installPhase = ''
    mkdir -p $out/lib/pkgconfig $out
    cp libndpip.a $out/lib/
    cp ndpip.pc $out/lib/pkgconfig/
    cp -r include $out/
  '';
}

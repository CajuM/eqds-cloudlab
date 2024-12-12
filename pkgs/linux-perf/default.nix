{ stdenv
, lib
, pkg-config
}:

stdenv.mkDerivation rec {
  pname = "linux-perf";
  version = "0";
  src = ./.;

  nativeBuildInputs = [ pkg-config ];

  dontStrip = true;

  CFLAGS = lib.concatStringsSep " " [ ];

  installPhase = ''
    mkdir -p $out/bin
    cp linux-perf $out/bin/
  '';

  enableParallelBuilding = true;
}

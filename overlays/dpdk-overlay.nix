(
  self: super:
  let
    optStdenv = super.optStdenv;
  in
  rec {
    dpdk =
      (super.dpdk.overrideAttrs (old: rec {
        version = "23.11.1";

        src = self.fetchurl {
          url = "https://fast.dpdk.org/rel/dpdk-${version}.tar.xz";
          sha256 = "sha256-EilbAaNFei+A8RkDA61yxPNdXZ/Fzue+KwYCcJf0kDA=";
        };

        dontStrip = true;
        outputs = self.lib.lists.remove "doc" old.outputs;

        postPatch = ''
          sed -i "s/subdir('doc')//g" meson.build
        '';

        mesonFlags =
          (self.lib.lists.foldl (acc: e: self.lib.lists.remove e acc) old.mesonFlags [ "-Denable_docs=true" ])
          ++ [
            "-Denable_docs=false"
            "-Denable_apps=dumpcap,pdump,proc-info,test-pmd"
          ];
      })).override {
        stdenv = self.myStdenv;
	machine = super.machine;
      };

    optDpdk = (dpdk.override { stdenv = optStdenv; }).overrideAttrs (old: {
      postPatch =
        old.postPatch
        + ''
          sed -i "s/'ar'/'${optStdenv.targetPlatform.config}-ar'/g" buildtools/meson.build
        '';
    });
  }
)

(self: super: rec {
  myStdenv = super.stdenvAdapters.addAttrsToDerivation {
    NIX_CFLAGS_COMPILE = self.lib.concatStringsSep " " self.extraCFlags;
  } super.gcc9Stdenv;

  dbgStdenv = super.stdenvAdapters.addAttrsToDerivation {
    NIX_CFLAGS_COMPILE = self.lib.concatStringsSep " " (
      self.extraCFlags ++ [
        "-g"
        "-Og"
        "-fsanitize=address"
       ]
    );
  } myStdenv;
})

{ pkgs ? import <nixpkgs> { } }:

pkgs.mkShell {
  packages = with pkgs; [
    nixfmt-rfc-style
    gettext
    jq
    (python312.withPackages (
      ps: with ps; [
        ipython
        matplotlib
        numpy
      ]
    ))
  ];
}

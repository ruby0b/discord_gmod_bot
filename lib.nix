# from: https://github.com/winston0410/mkNodePackage
{ pkgs, lib, stdenv, npmlock2nix, ... }:

rec {
  mkNpmModule = { src }: npmlock2nix.node_modules { inherit src; };
  mkNpmPackage = { pname, src, version, buildInputs ? [ ], buildPhase ? "", installPhase }:
    let
      nodeModules = mkNpmModule { inherit src; };
      nmPath = "${nodeModules + /node_modules}";
    in
    (stdenv.mkDerivation {
      inherit pname version src;
      buildInputs = with pkgs; [ nodejs ] ++ buildInputs;

      buildPhase = ''
        ln -s ${nmPath} ./node_modules
        ${buildPhase}
      '';
      installPhase = ''
        ${installPhase}
      '';
    });
}

{
  description = "DeepSeek Harness package flake";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

  outputs = {nixpkgs, ...}: let
    system = "x86_64-linux";
    pkgs = import nixpkgs {inherit system;};
    deepseek-harness = pkgs.callPackage ./package.nix {};
  in {
    packages.${system} = {
      default = deepseek-harness;
      inherit deepseek-harness;
    };

    apps.${system}.default = {
      type = "app";
      program = "${deepseek-harness}/bin/dsh";
      meta.description = "Run DeepSeek Harness";
    };

    checks.${system}.smoke =
      pkgs.runCommand "deepseek-harness-smoke" {
        nativeBuildInputs = [deepseek-harness];
      } ''
        test "$(dsh --version)" = "0.1.1-rc.2"
        dsh --help >/dev/null
        DSH_HOME="$TMPDIR/dsh-home" PATH=/does-not-exist \
          ${deepseek-harness}/bin/dsh plugin --profile web --help >/dev/null
        touch "$out"
      '';

    formatter.${system} = pkgs.alejandra;
  };
}

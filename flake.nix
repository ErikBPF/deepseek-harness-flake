{
  description = "DeepSeek Harness package flake";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

  outputs = {nixpkgs, ...}: let
    system = "x86_64-linux";
    pkgs = import nixpkgs {inherit system;};
    emptyCatalog = {
      packages = {};
      plugins = {};
      profiles = {};
    };
    mkHarness = catalog: pkgs.callPackage ./package.nix {inherit catalog;};
    catalog = import ./plugins.nix;
    deepseek-harness = mkHarness catalog;
    deepseek-harness-core = mkHarness emptyCatalog;
    missingReference = builtins.tryEval (mkHarness {
      packages = {};
      plugins = {};
      profiles.broken = {
        command = "dsh-broken";
        plugins = ["missing"];
      };
    });
    duplicateCommand = builtins.tryEval (mkHarness {
      packages = {};
      plugins = {};
      profiles = {
        one = {command = "dsh-same";};
        two = {command = "dsh-same";};
      };
    });
  in {
    packages.${system} = {
      default = deepseek-harness;
      inherit deepseek-harness deepseek-harness-core;
    };

    apps.${system}.default = {
      type = "app";
      program = "${deepseek-harness}/bin/dsh";
      meta.description = "Run DeepSeek Harness";
    };

    checks.${system} = {
      smoke =
        pkgs.runCommand "deepseek-harness-smoke" {
          nativeBuildInputs = [pkgs.coreutils pkgs.util-linux];
        } ''
          ${pkgs.bash}/bin/bash ${./tests/smoke.sh} ${deepseek-harness} ${deepseek-harness-core}
          touch "$out"
        '';

      catalog-validation = assert !missingReference.success;
      assert !duplicateCommand.success;
        pkgs.runCommand "deepseek-harness-catalog-validation" {} ''
          touch "$out"
        '';
    };

    formatter.${system} = pkgs.alejandra;
  };
}

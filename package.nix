{
  lib,
  buildNpmPackage,
  makeWrapper,
  nodejs_24,
  pnpm,
  catalog ? {
    packages = {};
    plugins = {};
    profiles = {};
  },
}: let
  inherit (catalog) packages plugins profiles;
  packageNames = map (package: package.packageName) (lib.attrValues packages);
  pluginPackageRefs = map (plugin: plugin.package) (lib.attrValues plugins);
  profilePluginRefs = lib.concatMap (profile: profile.plugins or []) (lib.attrValues profiles);
  missingPackageRefs = lib.filter (name: !builtins.hasAttr name packages) pluginPackageRefs;
  missingPluginRefs = lib.filter (name: !builtins.hasAttr name plugins) profilePluginRefs;
  pluginBundles = map (plugin: packages.${plugin.package}.packageName) (lib.attrValues plugins);
  commands = map (profile: profile.command) (lib.attrValues profiles);
  duplicates = values:
    lib.filter
    (value: builtins.length (lib.filter (candidate: candidate == value) values) > 1)
    (lib.unique values);
  harnessSrc = lib.fileset.toSource {
    root = ./.;
    fileset = lib.fileset.unions [./package.json ./package-lock.json];
  };

  builtPackages = lib.mapAttrs (name: package:
    buildNpmPackage {
      pname = "deepseek-harness-plugin-${name}";
      inherit (package) version src npmDepsHash;
      npmFlags = package.npmFlags or [];
      nodejs = nodejs_24;
      dontNpmBuild = true;
      installPhase = ''
        runHook preInstall
        mkdir -p "$out"
        cp -r node_modules "$out/"
        cp -r "node_modules/${package.packageName}" "$out/package"
        runHook postInstall
      '';
    })
  packages;

  packageCopies = lib.concatStringsSep "\n" (lib.mapAttrsToList (name: package: ''
      plugin_path="$out/libexec/node_modules/${package.packageName}"
      mkdir -p "$(dirname "$plugin_path")"
      cp -r --no-preserve=mode ${builtPackages.${name}}/package "$plugin_path"
      ln -s ${builtPackages.${name}}/node_modules "$plugin_path/node_modules"
      ${lib.concatMapStringsSep "\n" (patch: ''
        patch -d "$out/libexec" -p1 < ${patch}
      '') (package.patches or [])}
    '')
    packages);

  dependencyLines = lib.concatStrings (lib.mapAttrsToList (_: plugin: let
      package = packages.${plugin.package};
    in ''
      ${builtins.toJSON package.packageName}: ${builtins.toJSON package.version},
    '')
    plugins);

  profileTemplates = lib.concatStringsSep ", " (lib.mapAttrsToList (name: profile: "${builtins.toJSON name}: ${builtins.toJSON {
      bundles = ["@deepseek-ai/dsh-base"] ++ map (plugin: packages.${plugins.${plugin}.package}.packageName) (profile.plugins or []);
      patchReload = profile.patchReload or "live";
    }}")
    profiles);

  profilePatchCopies = lib.concatStringsSep "\n" (lib.mapAttrsToList (name: profile:
    lib.concatStringsSep "\n" (lib.imap0 (index: patch: ''
        mkdir -p "$out/share/deepseek-harness/profiles/${name}"
        cp ${patch} "$out/share/deepseek-harness/profiles/${name}/${toString index}.yml"
      '')
      (profile.patches or [])))
  profiles);
  wrapperFlags = flags: lib.concatMapStrings (flag: " --add-flags ${lib.escapeShellArg flag}") flags;
  profileWrappers = lib.concatStringsSep "\n" (lib.mapAttrsToList (name: profile: let
      patchFlags = lib.concatStrings (lib.imap0 (index: _: " --add-flags \"--patch\" --add-flags \"$out/share/deepseek-harness/profiles/${name}/${toString index}.yml\"") (profile.patches or []));
    in ''
      makeWrapper ${nodejs_24}/bin/node "$out/bin/${profile.command}" --add-flags "--expose-internals" --add-flags "$out/libexec/node_modules/@deepseek-ai/dsh/lib/bin.js" --add-flags "--profile" --add-flags ${lib.escapeShellArg name}${patchFlags}${wrapperFlags (profile.args or [])} --prefix PATH : ${lib.makeBinPath [pnpm]}
    '')
    profiles);
in
  assert lib.assertMsg (missingPackageRefs == []) "plugin catalog: missing package reference(s): ${lib.concatStringsSep ", " missingPackageRefs}";
  assert lib.assertMsg (missingPluginRefs == []) "plugin catalog: missing plugin reference(s): ${lib.concatStringsSep ", " missingPluginRefs}";
  assert lib.assertMsg (duplicates packageNames == []) "plugin catalog: duplicate package name(s): ${lib.concatStringsSep ", " (duplicates packageNames)}";
  assert lib.assertMsg (duplicates pluginBundles == []) "plugin catalog: duplicate bundle(s): ${lib.concatStringsSep ", " (duplicates pluginBundles)}";
  assert lib.assertMsg (duplicates commands == []) "plugin catalog: duplicate command(s): ${lib.concatStringsSep ", " (duplicates commands)}";
  assert lib.assertMsg (!builtins.elem "dsh" commands) "plugin catalog: profile command must not replace dsh";
    buildNpmPackage rec {
      pname = "deepseek-harness";
      version = "0.1.2-rc.1";
      src = harnessSrc;
      nodejs = nodejs_24;
      npmDepsHash = "sha256-m6lFpm4AWK0M8l97ACFGUausLbFN+xGcZRQc1Wk4hgI=";
      npmFlags = ["--force"];
      dontNpmBuild = true;
      nativeBuildInputs = [makeWrapper];

      installPhase = ''
        runHook preInstall
        ${lib.optionalString (profiles != {}) ''
          # ponytail: patch bootstrap table until upstream accepts external templates.
          substituteInPlace node_modules/@deepseek-ai/dsh-app-boot/lib/index.js \
            --replace-fail 'const PROFILE_TEMPLATES = {' \
            'const PROFILE_TEMPLATES = { ${profileTemplates},'
        ''}
        mkdir -p "$out/libexec"
        cp -r node_modules "$out/libexec/"
        ${packageCopies}
        ${profilePatchCopies}
        ${lib.optionalString (plugins != {}) ''
          substituteInPlace "$out/libexec/node_modules/@deepseek-ai/dsh/package.json" \
            --replace-fail '"dependencies": {' '"dependencies": {${dependencyLines}'
        ''}
        makeWrapper ${nodejs_24}/bin/node "$out/bin/dsh" \
          --add-flags "--expose-internals" \
          --add-flags "$out/libexec/node_modules/@deepseek-ai/dsh/lib/bin.js" \
          --prefix PATH : ${lib.makeBinPath [pnpm]}
        ${profileWrappers}
        runHook postInstall
      '';

      meta = {
        description = "DeepSeek's plugin-based agent harness";
        homepage = "https://github.com/deepseek-ai/deepseek-harness";
        license = lib.licenses.mit;
        mainProgram = "dsh";
        platforms = ["x86_64-linux"];
      };
    }

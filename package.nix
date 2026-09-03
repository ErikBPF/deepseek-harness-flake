{
  lib,
  buildNpmPackage,
  makeWrapper,
  nodejs_24,
  pnpm,
}:
buildNpmPackage rec {
  pname = "deepseek-harness";
  version = "0.1.2-rc.1";
  src = ./.;

  nodejs = nodejs_24;
  npmDepsHash = "sha256-m6lFpm4AWK0M8l97ACFGUausLbFN+xGcZRQc1Wk4hgI=";
  npmFlags = ["--force"];
  dontNpmBuild = true;

  nativeBuildInputs = [makeWrapper];

  installPhase = ''
    runHook preInstall
    mkdir -p "$out/libexec"
    cp -r node_modules "$out/libexec/"
    makeWrapper ${nodejs_24}/bin/node "$out/bin/dsh" \
      --add-flags "--expose-internals" \
      --add-flags "$out/libexec/node_modules/@deepseek-ai/dsh/lib/bin.js" \
      --prefix PATH : ${lib.makeBinPath [pnpm]}
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

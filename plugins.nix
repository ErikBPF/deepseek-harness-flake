{
  packages.tui = {
    packageName = "@dsh-tui/dsh-tui";
    version = "0.1.2";
    src = ./plugins/tui;
    npmDepsHash = "sha256-hWla9iHzWc0BcgiNkXJwbsifXzu1EXCN9/lzU0pgsf8=";
    npmFlags = ["--legacy-peer-deps"];
    patches = [./plugins/tui/alpha-compat.patch];
  };

  plugins.tui.package = "tui";

  profiles.tui = {
    command = "dsh-tui";
    plugins = ["tui"];
    patches = [./plugins/tui/providers.patch.yml];
    args = [];
  };
}

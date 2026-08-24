#!/usr/bin/env bash
set -euo pipefail

repo="$(git rev-parse --show-toplevel)"
package="$(nix build "path:$repo#deepseek-harness" --no-link --print-out-paths)"
dsh_tmp="$(mktemp -d)"

test "$("$package/bin/dsh" --version)" = "0.1.1-rc.2"
"$package/bin/dsh" --help >/dev/null
DSH_HOME="$dsh_tmp" PATH=/does-not-exist \
  "$package/bin/dsh" plugin --profile web --help >/dev/null

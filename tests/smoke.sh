#!/usr/bin/env bash
set -euo pipefail

if [[ $# -gt 0 ]]; then
  package="$1"
else
  repo="$(git rev-parse --show-toplevel)"
  package="$(nix build "path:$repo#deepseek-harness" --no-link --print-out-paths)"
fi
dsh_tmp="$(mktemp -d)"
web_log="$dsh_tmp/web.log"

test "$("$package/bin/dsh" --version)" = "0.1.2-rc.1"
"$package/bin/dsh" --help >/dev/null
DSH_HOME="$dsh_tmp" PATH=/does-not-exist \
  "$package/bin/dsh" plugin --profile web --help >/dev/null

set +e
DSH_HOME="$dsh_tmp" timeout 5 "$package/bin/dsh" web --no-open >"$web_log" 2>&1
web_status=$?
set -e
if [[ $web_status -ne 124 ]]; then
  cat "$web_log"
  exit 1
fi
grep -F "dsh web: http://127.0.0.1:3080" "$web_log" >/dev/null

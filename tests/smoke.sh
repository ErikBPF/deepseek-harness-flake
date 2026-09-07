#!/usr/bin/env bash
set -euo pipefail

if [[ $# -eq 2 ]]; then
  package="$1"
  core_package="$2"
else
  repo="$(git rev-parse --show-toplevel)"
  package="$(nix build "path:$repo#deepseek-harness" --no-link --print-out-paths)"
  core_package="$(nix build "path:$repo#deepseek-harness-core" --no-link --print-out-paths)"
fi
dsh_tmp="$(mktemp -d)"
dsh_web_home="$dsh_tmp/web-home"
dsh_tui_home="$dsh_tmp/tui-home"
web_log="$dsh_tmp/web.log"
tui_log="$dsh_tmp/tui.log"
tui_command_log="$dsh_tmp/tui-command.log"
tui_config="$dsh_tmp/tui-config.yml"
trap 'rm -rf "$dsh_tmp"' EXIT

test "$("$package/bin/dsh" --version)" = "0.1.2-rc.1"
test "$("$core_package/bin/dsh" --version)" = "0.1.2-rc.1"
"$package/bin/dsh" --help >/dev/null
test ! -e "$core_package/bin/dsh-tui"
test ! -e "$core_package/libexec/node_modules/@dsh-tui/dsh-tui"

set +e
DSH_HOME="$dsh_web_home" timeout 5 "$core_package/bin/dsh" web --no-open >"$web_log" 2>&1
web_status=$?
set -e
if [[ $web_status -ne 124 ]]; then
  cat "$web_log"
  exit 1
fi
grep -F "dsh web: http://127.0.0.1:3080" "$web_log" >/dev/null

grep -F '"version": "0.1.2"' \
  "$package/libexec/node_modules/@dsh-tui/dsh-tui/package.json" >/dev/null
grep -F 'model: deepseek-v4-pro' \
  "$package/libexec/node_modules/@dsh-tui/dsh-tui/cordis.patch.yml" >/dev/null
tui_bundle="$package/libexec/node_modules/@dsh-tui/dsh-tui/cordis.patch.yml"
if grep -F 'model: deepseek-v4-flash' "$tui_bundle" >/dev/null; then
  echo "TUI bundle must retain upstream model policy" >&2
  exit 1
fi
if grep -F 'id: storage' "$tui_bundle" >/dev/null; then
  echo "TUI alpha compatibility bundle must not duplicate storage" >&2
  exit 1
fi
grep -F 'import { assertNever } from "@deepseek-ai/dsh-util-values";' \
  "$package/libexec/node_modules/@dsh-tui/dsh-tui/lib/index.js" >/dev/null
DSH_HOME="$dsh_tui_home" PATH=/does-not-exist \
  "$package/bin/dsh-tui" --dump-config >"$tui_config"
grep -F 'provider: litellm-homelab' "$tui_config" >/dev/null
grep -F 'model: deepseek-v4-flash' "$tui_config" >/dev/null
grep -F 'https://litellm.homelab.pastelariadev.com/v1' "$tui_config" >/dev/null
grep -F 'apiKeyEnv: LITELLM_HOMELAB_API_KEY' "$tui_config" >/dev/null
grep -E 'x-opencode-session: .+' "$tui_config" >/dev/null
grep -F 'id: qwen-chat' "$tui_config" >/dev/null
grep -F 'https://llm-gateway-dataplatform-dev.nstech.com.br/v1' "$tui_config" >/dev/null
grep -F 'apiKeyEnv: LITELLM_DATAPLATFORM_DEV_API_KEY' "$tui_config" >/dev/null
grep -F 'id: chatgpt-5.6-luna' "$tui_config" >/dev/null
grep -F 'openai-codex:' "$tui_config" >/dev/null
grep -F 'id: gpt-5.6-sol' "$tui_config" >/dev/null
grep -F 'id: gpt-5.6-terra' "$tui_config" >/dev/null
grep -F 'id: gpt-5.6-luna' "$tui_config" >/dev/null
grep -Fx '[]' "$dsh_tui_home/profiles/tui/cordis.patch.yml" >/dev/null
grep -F '"@dsh-tui/dsh-tui"' "$dsh_tui_home/profiles/tui/package.json" >/dev/null

set +e
DSH_HOME="$dsh_tui_home" DSH_TELEMETRY_DISABLED=1 TERM=xterm-256color \
  timeout 5 script -qec "$package/bin/dsh-tui" /dev/null >"$tui_log" 2>&1
tui_status=$?
set -e
if [[ $tui_status -ne 124 ]]; then
  cat "$tui_log"
  exit 1
fi
grep -F $'\033[?2004h' "$tui_log" >/dev/null

set +e
{ sleep 2; printf '/help\r'; sleep 2; printf '\004'; } |
  DSH_HOME="$dsh_tui_home" DSH_TELEMETRY_DISABLED=1 TERM=xterm-256color \
    timeout 8 script -qfec "$package/bin/dsh-tui" /dev/null >"$tui_command_log" 2>&1
tui_command_status=$?
set -e
if [[ $tui_command_status -ne 0 ]]; then
  cat "$tui_command_log"
  exit 1
fi
grep -F 'Keyboard shortcuts' "$tui_command_log" >/dev/null
test -L "$dsh_tui_home/profiles/node_modules/@dsh-tui/dsh-tui"

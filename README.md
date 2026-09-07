# DeepSeek Harness flake

Packages DeepSeek Harness `0.1.2-rc.1` with the approved plugin catalog in
[`plugins.nix`](./plugins.nix). `deepseek-harness` is the full/default output;
`deepseek-harness-core` is the plugin-free recovery output.

## Runtime credentials

Pass secret tokens through the launching process environment. Harness preserves
inherited variables; the official provider key comes from
`DEEPSEEK_API_KEY` and its optional endpoint from `DEEPSEEK_BASE_URL`.

```bash
DEEPSEEK_API_KEY="$(< /run/secrets/deepseek-api-key)" \
  nix run . -- web --no-open
```

The TUI profile declares two LiteLLM routes and only their variable names.
The homelab route exposes `deepseek-v4-flash`, `deepseek-v4-pro`, and local
`qwen-chat`; it also sends the TUI session ID as `x-opencode-session` for
LiteLLM to forward only on OpenCode-backed models.

```yaml
litellm-homelab:
  baseURL: https://litellm.homelab.pastelariadev.com/v1
  apiKeyEnv: LITELLM_HOMELAB_API_KEY
litellm-dataplatform-dev:
  baseURL: https://llm-gateway-dataplatform-dev.nstech.com.br/v1
  apiKeyEnv: LITELLM_DATAPLATFORM_DEV_API_KEY
```

The same profile exposes `gpt-5.6-sol`, `gpt-5.6-terra`, and `gpt-5.6-luna`
through the native `openai-codex` provider. It uses Harness's interactive
ChatGPT OAuth flow and credential store; no Codex API-key variable belongs in
the flake or shell environment.

Inject each value only when starting Harness:

```bash
package="$(nix build .#deepseek-harness --no-link --print-out-paths)"
LITELLM_HOMELAB_API_KEY="$(< /run/vault-agent/deepseek-harness-litellm)" \
LITELLM_DATAPLATFORM_DEV_API_KEY="$(< /run/credentials/dsh/dataplatform-litellm)" \
  "$package/bin/dsh-tui"
```

Inherited environment has precedence over the launch directory's `.env`, then
`$DSH_HOME/.env`. Prefer a Vault-agent or systemd credential render for
deployed secrets. Never put token values in `flake.nix`, `plugins.nix`, Nix
arguments, profile patches, or command-line arguments: they can enter the Nix
store, derivation metadata, process listings, or Git.

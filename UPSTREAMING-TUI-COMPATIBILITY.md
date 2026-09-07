# Upstreaming the TUI compatibility patch

**Status:** downstream workaround verified; upstream contribution proposed

**Proven pairing:** `@dsh-tui/dsh-tui@0.1.2` with `@deepseek-ai/dsh@0.1.2-rc.1`

The patch was first verified against alpha.5. On 2026-09-07, the combined
rc.1 package passed the catalog checks, core Web startup, TUI render, and
`/help` pseudo-terminal smoke test. The earlier deployed canary below remains
historical evidence; rc.1 has not been deployed by this reconciliation.

## Why this exists

TUI 0.1.2 targets the older Harness RC contracts. With Harness alpha.5, the
interface initially rendered blank and slash commands such as `/clear` failed
with `Cannot read properties of undefined (reading 'aborted')`. The latter was
an argument-shape mismatch: Harness added an image-attachment argument to
`commands.execute`, while the TUI still passed the abort signal as argument
three.

This repository applies [`plugins/tui/alpha-compat.patch`](plugins/tui/alpha-compat.patch)
while building the pinned npm package. The patch adapts these upstream-owned
contracts:

- imports `assertNever` from its new package;
- reads sessions through `snapshotEvents()` instead of the removed public
  `events` property;
- handles user questions through the agent-scoped request waterfall;
- explicitly injects and retains the `tuiPrompt` service used by deferred
  render callbacks;
- calls `commands.execute(agent, line, [], signal)` for commands submitted
  without images; and
- removes storage services already supplied by the Harness base bundle.

The pseudo-terminal smoke test in [`tests/smoke.sh`](tests/smoke.sh) proves a
real render and executes `/help`. The deployed Endeavour canary also ran
`/help`, `/clear`, and `/help` through the SecretSpec wrapper without a command
failure.

## Upstream boundary

The compatibility code belongs in [`dsh-tui/dsh-tui`](https://github.com/dsh-tui/dsh-tui).
The Nix catalog, LiteLLM routes, model defaults, SecretSpec handoff, and machine
deployment are homelab policy and must remain downstream.

Harness owns the changed service contracts. As checked on 2026-09-04, its
[`CONTRIBUTING.md`](https://github.com/deepseek-ai/deepseek-harness/blob/master/CONTRIBUTING.md)
does not accept external pull requests, so any request for migration notes or
an adapter compatibility contract should go to
[DeepSeek Harness Discussions](https://github.com/deepseek-ai/deepseek-harness/discussions),
not a code PR.

## Proposed contribution path

1. Open a focused bug in
   [`dsh-tui/dsh-tui`](https://github.com/dsh-tui/dsh-tui/issues) with the exact
   version pair, the blank-render and slash-command symptoms, and the keyless
   reproduction. Link this downstream patch as working evidence once this
   repository is published.
2. Agree on the target Harness prerelease before coding. At the same checkpoint,
   TUI [`main`](https://github.com/dsh-tui/dsh-tui/blob/main/package.json) still
   declares RC-era peers, while Harness has moved beyond alpha.5. Rebase the
   adaptation onto the maintainer-selected current `@deepseek-ai/dsh@next`;
   do not widen peer ranges until that pairing passes.
3. Submit one compatibility PR to TUI `main`. Change the TypeScript sources
   (`src/index.ts`, `src/chat/helpers.ts`, `src/chat/tokens.ts`,
   `src/chat/questions.ts`, and `src/chat/skill-invocation.ts`), the bundle,
   peer metadata, and lockfile. Do not submit edits to generated release
   JavaScript.
4. Extend the existing `tests/tui.spec.ts` `/clear` coverage so command
   dispatch proves the attachment list and abort signal reach the current
   Harness API. Retain coverage for initial render, question handling, session
   replay, and bundle composition. Run `pnpm typecheck`, `pnpm test`, and
   `pnpm build`.
5. After an upstream release, bump the TUI pin and Nix hash here, delete
   `alpha-compat.patch`, run `nix flake check path:.`, then update consumers
   leaf-first. The patch is retired only when a fresh immutable build passes
   the pseudo-terminal command canary without downstream source changes.

Separately, open a Harness Discussion proposing release-note callouts for
adapter-breaking service changes: old and new signatures, replacement APIs,
and the first compatible TUI version. That improves the ecosystem without
asking Harness to own this out-of-tree UI.

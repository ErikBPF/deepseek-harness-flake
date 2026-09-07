# Declarative plugin catalog

**Status:** Implemented and verified

## Seed

### Destination

One maintainer-owned catalog declares reproducible npm payloads, activated DSH
plugins, and profile configuration. The full Harness package composes that
catalog; a core package remains available for rollback and diagnosis.

### Motivation

The first packaged plugin, `@dsh-tui/dsh-tui`, currently requires repeated
TUI-specific build, profile, dependency, wrapper, and configuration logic.
Adding another approved plugin should change catalog data and its pinned npm
payload, not the generic Harness composer.

### Constraints

- Every npm payload has an exact version, committed lockfile, and Nix hash.
- Profiles use DSH's native bundle and `--patch` layering.
- Builds and deployment never run mutable `dsh plugin add`.
- Existing Web behavior and the TUI pseudo-terminal canary remain green.
- TUI defaults to `litellm-homelab/deepseek-v4-flash`, exposes local
  `qwen-chat`, the separate `litellm-dataplatform-dev` route, and the native
  `openai-codex` GPT-5.6 catalog.
- The homelab route emits the TUI session ID as `x-opencode-session`; LiteLLM
  owns model-scoped forwarding to OpenCode.
- A pinned package may supply a reviewed compatibility bundle when its upstream
  bundle targets a different Harness prerelease.
- Profile patches declare one credential variable per LiteLLM trust boundary;
  secret values enter through the runtime environment and never the Nix store.

### Non-goals

- Arbitrary downstream npm strings or an unpinned public plugin API.
- Runtime plugin discovery, installation, or automatic updates.
- Supporting non-npm plugin ecosystems before one is needed.
- Gemini workspace, provider credential, or deployment changes.

## Party ledger

- **Product/domain:** one reviewed catalog should expose package pins, plugin
  activation, and profile options without hiding what ships.
- **Developer/architect:** package payload, DSH bundle activation, and runtime
  profile are different relationships; represent them separately and keep the
  composer generic.
- **Tester/operator:** retain a plugin-free core output, reject broken catalog
  references and command collisions, and boot the real TUI in a pseudo-TTY.
- **CodeHero/security:** accept only repository-owned lockfiles and Nix-store
  patches; preserve npm audit, no-secret, and no-runtime-install boundaries.

The initial disagreement was whether one flat plugin record was enough. The
accepted catalog keeps `packages`, `plugins`, and `profiles` as separate
sections because one npm payload may support multiple activations or profiles.

## Decision map

### Actors and outcomes

| Actor | Outcome |
|---|---|
| Maintainer | Adds or updates one approved plugin through catalog data and its locked payload. |
| Nix builder | Produces deterministic core and full packages without network access during installation. |
| Operator | Runs stable profile commands and can fall back to core Harness or Web. |

### Decisions

| ID | Decision | Evidence | Consequence |
|---|---|---|---|
| D1 | One catalog owns `packages`, `plugins`, and `profiles`. | These are the three distinct seams in DSH packaging and boot. | Generic composition replaces TUI-specific branches. |
| D2 | Package entries point to repository-owned npm manifests/locks and fixed Nix hashes. | TUI prerelease peer metadata cannot safely share Harness's npm solve. | Each payload remains independently reproducible. |
| D3 | Plugin entries map a DSH bundle name to one package entry. | DSH resolves bundle patches by npm package identity. | Profile composition need not know npm build details. |
| D4 | Profile entries select ordered plugins, wrapper command, arguments, and ordered immutable patch files. Package entries may replace an incompatible upstream bundle. | DSH applies bundles in profile order and `--patch` after bundle layers; alpha.5 base duplicates storage rows from TUI 0.1.2. | Deployment policy remains in profile patches while compatibility stays pinned with package data. |
| D5 | Invalid references and duplicate package, bundle, or command identities fail evaluation/build. | Silent omission or overwrite produces packages that build but fail at runtime. | Catalog errors fail before deployment. |
| D6 | Expose core and full package outputs; default remains full. | Web/core is the recovery surface for third-party plugin failure. | Rollback does not require editing the catalog. |

### Dependencies

```text
locked package payloads -> plugin activation -> profile composition
                        -> full package -> smoke and pseudo-TTY canary
core package ---------------------------------> rollback surface
```

### Risks and review gates

- **Supply chain:** exact package versions, lockfiles, hashes, and npm audits.
- **Compatibility:** real config dump plus pseudo-TTY boot against pinned DSH.
- **Architecture:** composer contains no plugin-specific package names or model
  policy.
- **Operations:** Web and core outputs remain usable if a plugin is removed.

### Out of scope

- Runtime mutation and mutable profile dependency installs.
- Automatic catalog discovery from directories or registries.
- Consumer-provided unreviewed plugins.

### Frontier

Implementation and verification are complete. A future plugin repeats the
catalog pin, compatibility patch if needed, and runtime canary.

## PL grill findings applied

1. **False extensibility:** a catalog with TUI strings left in the composer is
   only indirection. Added the architecture gate that plugin identity and model
   policy live outside the composer.
2. **Configuration ownership:** editing a vendored bundle patch would mix local
   policy with package material. Selected native immutable `--patch` overlays.
3. **Recovery:** a full-only output would couple Harness availability to every
   third-party plugin. Added a plugin-free core output.
4. **Silent breakage:** missing package/plugin references or identity collisions
   must fail before runtime. Added explicit catalog validation behavior.
5. **Ordering:** unordered plugin or patch composition would make precedence
   accidental. Catalog profiles preserve declared list order.

## Implementation plan

### Test seams

| Seam | Catches | Misses | Cost |
|---|---|---|---|
| Nix evaluation assertions | Missing references and duplicate identities before a build. | Runtime module resolution. | Fast. |
| Full/core smoke packages | Output split, profile bootstrap, immutable config, Web boot, and real pseudo-TTY boot. | Provider calls requiring credentials. | Two local Nix builds plus bounded canaries. |
| npm audit per lockfile | Known dependency advisories. | Behavior and unpublished threats. | Networked maintenance check; not a sandboxed build gate. |

### Slice 1: Validated catalog and recovery output

**Behavior:** plugin-free recovery package; invalid catalogs fail.

**RED**

- Extend the smoke contract to require distinct full and core packages; expect
  failure because the core output does not exist.
- Add evaluation checks for a missing plugin reference and duplicate wrapper
  command; expect both catalogs to evaluate successfully before validation is
  implemented.

**GREEN**

- Add one repository-owned catalog with `packages`, `plugins`, and `profiles`.
- Validate references and unique package, bundle, profile, and command
  identities at evaluation.
- Expose `deepseek-harness-core` and the catalog-composed
  `deepseek-harness`; retain full as `default`.

**Verify:** `nix flake check path:.`; core reports the pinned Harness version,
has no catalog plugin payload, and boots Web.

**Ownership/dependencies:** this leaf repository; no consumer change. Land
before any downstream output pin update. Roll back by selecting
`deepseek-harness-core`.

### Slice 2: Generic composition and immutable profile policy

**Behavior:** full package contains TUI, applies provider/model policy, and
starts from an empty Harness home without runtime installation.

**RED**

- Require the TUI source under the catalog package entry and the effective
  config to contain both LiteLLM routes, distinct credential variables, and
  the Flash default while policy remains outside the package compatibility
  patch; expect the TUI-specific composer mutation to fail.
- Run the pseudo-TTY canary with an empty `DSH_HOME` and unusable `PATH`;
  expect module resolution to fail until catalog dependencies enter the
  immutable closure.

**GREEN**

- Build each catalog npm payload independently from its lockfile and hash.
- Generate DSH profile templates, dependency visibility, commands, arguments,
  and ordered `--patch` flags from catalog data only.
- Move local provider/model policy to an immutable profile patch and remove
  TUI names and policy from the composer.

**Verify:** `nix flake check path:.`, `npm audit --package-lock-only` for the
Harness and TUI locks, and `git diff --check`.

**Ownership/dependencies:** this leaf repository. Default/full rollout is
safe only after both Web and TUI canaries pass; operational rollback remains
the core output.

### IP grill and risk review

- **Anti-consensus:** a flat plugin list is shorter, but cannot represent the
  requested independent package, activation, and profile/config seams without
  repeating build data.
- **Pre-mortem:** the most likely green build/red runtime failure is an absent
  plugin dependency in DSH's fallback `node_modules`; the empty-home
  pseudo-TTY canary covers it.
- **Security:** only exact repository lockfiles, fixed hashes, and Nix-store
  patches enter the package; no credential or mutable npm input is accepted.
- **Compatibility/operations:** core Web boot and full TUI boot are separate
  gates, preserving a usable rollback surface.
- **Simplicity:** one catalog and the existing package/smoke files; no schema
  library, discovery mechanism, registry, or consumer extension API.

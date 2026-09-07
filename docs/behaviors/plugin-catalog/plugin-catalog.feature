@unautomated
Feature: Declarative DeepSeek Harness plugin catalog
  Approved plugins are packaged and configured from one reproducible catalog
  without runtime installation or plugin-specific composer logic.

  Scenario: Build the full package from the approved catalog
    Given the catalog contains the pinned TUI package and plugin
    When the full DeepSeek Harness package is built
    Then the package contains TUI version "0.1.2"
    And its bundle is compatible with Harness "0.1.2-rc.1"
    And the "dsh-tui" command starts its declared profile in a terminal

  Scenario: Apply immutable profile configuration
    Given the TUI profile declares the reviewed configuration patch
    When its effective configuration is dumped
    Then the default model is "litellm-homelab/deepseek-v4-flash"
    And "litellm-homelab/qwen-chat" is selectable
    And the "litellm-dataplatform-dev" provider is independently selectable
    And the native "openai-codex" provider exposes the three approved GPT models
    And the homelab route sends the stable TUI session header
    And each provider names a distinct runtime credential variable
    And the profile's writable user patch remains independent

  Scenario: Keep a plugin-free recovery package
    Given the approved catalog contains third-party plugins
    When the core DeepSeek Harness package is built
    Then the core package contains no catalog plugin
    And its Web profile still starts

  Scenario: Reject an invalid catalog relationship
    Given a profile references a missing plugin or duplicates a catalog identity
    When the catalog is evaluated
    Then evaluation fails with the invalid relationship identified

  Scenario: Avoid mutable plugin installation
    Given the full package was built from the approved catalog
    When a declared profile starts with an empty Harness home
    Then its dependencies resolve from the immutable package closure
    And no package manager installs a runtime dependency

# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.1.0] — Unreleased

Initial release: a Model Context Protocol server (stdio transport, built on [anubis_mcp](https://hex.pm/packages/anubis_mcp)) exposing the Localize API to AI agents through eleven tools.

### Highlights

* **Discovery:** `localize_search` (multi-word keyword search over the documented API), `localize_browse` (modules by documentation group).
* **Documentation:** `localize_doc` (full `@doc` / `@spec`), `localize_examples` (curated snippets for formatting and for `~t` / Gettext / Phoenix / LiveView translation setup).
* **Schema:** `localize_options`, `localize_atoms`, `localize_errors`.
* **Resolution:** `localize_resolve_locale`, `localize_validate`.
* **Live invocation:** `localize_invoke` (allowlisted read-only functions, 5 s timeout, 64 MB heap cap) and `localize_term_grammar` (the JSON ↔ Elixir term grammar).

Calendrical and localize_web are detected at boot and folded into search / browse / doc / atoms when present. Only the documented API surface is indexed: hidden modules and functions are invisible to every tool. See the [README](https://hexdocs.pm/localize_mcp/readme.html) for installation and the [Host configuration guide](https://hexdocs.pm/localize_mcp/host_configuration.html) for wiring into Claude Code, Claude Desktop, Codex CLI, ChatGPT, and Zed.

# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.1.0] — Unreleased

Initial release. Implements the eleven-tool surface described in `plans/mcp_server.md` (in the `localize` repo):

* **Discovery:** `localize_search`, `localize_browse`.
* **Documentation:** `localize_doc`, `localize_examples`.
* **Schema:** `localize_options`, `localize_atoms`, `localize_errors`.
* **Resolution:** `localize_resolve_locale`, `localize_validate`.
* **Live invocation:** `localize_invoke`, `localize_term_grammar`.

Calendrical and localize_web are detected at boot via `Code.ensure_loaded?/1` and their API is folded into search / browse / doc / atoms when present.

# Localize MCP

A Model Context Protocol (MCP) server for the [Localize](https://github.com/elixir-localize/localize) internationalisation library and its optional companions [Calendrical](https://github.com/kipcole9/calendrical) and `localize_web`.

Exposes structured tools so AI agents can discover and use the Localize API directly, without grepping the source.

## Why

The Localize API surface is large — currencies, languages, scripts, territories, calendars, numbers, dates, times, intervals, durations, units, lists, messages, collation, locale displays, plural rules. AI agents that work with the library spend most of their tokens on discovery (which function takes which option, what atoms a locale resolves to, which exception covers which failure). This server turns each of those probes into a single typed tool call backed by BEAM introspection.

## Tools

| Tool | Purpose |
|---|---|
| `localize_search` | Keyword search across modules, functions, and docs. |
| `localize_browse` | List modules in a documentation group. |
| `localize_doc` | Full `@doc` / `@spec` for a module or function. |
| `localize_examples` | Curated example snippets keyed by capability. Covers per-domain formatting *and* message translation (`~t` sigil, Gettext setup, Phoenix / LiveView integration). |
| `localize_options` | Accepted options for a formatter, with allowed values. |
| `localize_atoms` | Closed atom collections — locales, calendars, currencies, etc. |
| `localize_errors` | All `Localize.*Error` modules with their `:reason` atoms. |
| `localize_resolve_locale` | Show how Localize canonicalises a locale input. |
| `localize_validate` | Kind-aware binary-input validator. |
| `localize_invoke` | Execute a whitelisted read-only function and return the result. |
| `localize_term_grammar` | The JSON ↔ Elixir term grammar `localize_invoke` accepts. |

## Installation

Two distribution channels.

### As a hex dependency

Add to `mix.exs`:

```elixir
def deps do
  [
    {:localize_mcp, "~> 0.1", only: :dev}
  ]
end
```

Then start the server with:

```sh
mix localize_mcp
```

### As a Mix archive (recommended for AI-host configs)

Install the archive once, system-wide, and reference it from any Claude Desktop / Claude Code / Zed config without per-project deps:

```sh
mix archive.install hex localize_mcp
```

Then start with:

```sh
~/.mix/escripts/localize_mcp
```

### Claude Desktop config

```json
{
  "mcpServers": {
    "localize": {
      "command": "mix",
      "args": ["localize_mcp"]
    }
  }
}
```

## Optional integrations

* **`Calendrical`** — when loaded, non-Gregorian calendar atoms (`:japanese`, `:hebrew`, `:islamic`, …) appear in `localize_atoms` with `collection: "calendars"`, and `localize_doc` resolves `Calendrical.*` module names.
* **`localize_web`** — when loaded, the Phoenix / Plug helpers appear in `localize_search` and `localize_browse` under a `"Web"` group, and a small allowlist of read-only request-locale helpers becomes invocable.

Both are detected at boot via `Code.ensure_loaded?/1`. The server runs identically with neither, either, or both present.

## Safety

* Live invocation is **allowlisted**. Anything not in `priv/mcp/invocable.exs` returns `not_invokable`.
* No process state is mutated. Each `localize_invoke` call runs inside a `Task.async/1` so the caller's process dictionary stays clean.
* Per-call resource caps: 5 second timeout, 64 MB heap limit, 16 KB input cap on the term grammar.

## Reading further

* [`guides/usage.md`](guides/usage.md) — the end-to-end usage guide. Start here if you're new.
* [`guides/host_configuration.md`](guides/host_configuration.md) — config schemas for Claude Desktop, Claude Code, and Zed.

## License

Apache 2.0.

# Using the Localize MCP server

A walk-through of what the server is for, how to install it, how to wire it into Claude Desktop / Claude Code / Zed, and how each of the eleven tools is meant to be used.

## What it does

The Localize API surface is large — currencies, languages, scripts, territories, calendars, numbers, dates, times, intervals, durations, units, lists, messages, collation, locale displays, plural rules. An AI agent that wants to use Localize correctly normally has to grep its way through the source to figure out which function it needs, which options that function takes, and which atom form is expected.

This MCP server replaces all of that grepping with eleven typed tool calls backed by BEAM introspection of the loaded Localize modules. After a session has the server attached, an agent's typical flow becomes:

> "Format 1234 as USD in German" → `localize_search("format currency")` → `localize_options("Localize.Number", "to_string", 2)` → `localize_invoke("Localize.Number.to_string/2", [1234, [format: :currency, currency: :USD, locale: :de]])`

— three calls, no source-file reads.

## Installing

You have three options, in increasing order of "set up once, forget".

### Option 1: As a project-local dev dependency

Add to your project's `mix.exs`:

```elixir
def deps do
  [
    {:localize_mcp, "~> 0.1", only: :dev}
  ]
end
```

Then `mix deps.get`. The server is invoked via `mix localize_mcp` from inside that project's directory. The Localize version your project pins is the version the agent sees.

### Option 2: As a standalone escript

Build the standalone binary once:

```sh
cd /path/to/localize_mcp
MIX_ENV=prod mix escript.build
```

Copy the resulting `localize_mcp` binary anywhere on your `PATH`:

```sh
cp localize_mcp ~/bin/
```

The binary embeds all of Localize at the version it was built against. It does not need an Elixir project in the calling directory. It does need an `erl` runtime on `PATH`.

### Option 3: As a Mix archive (recommended for AI hosts)

This is the "system-wide install, reference from any host config" path.

```sh
mix archive.install hex localize_mcp
```

(Or `mix archive.install ./localize_mcp-0.1.0.ez` if you've built the archive locally.) The archive lands at `~/.mix/escripts/localize_mcp`. Reference that absolute path from your AI host's config and you're done — no per-project changes needed when you want a new project to talk to the server.

## Wiring into Claude Desktop

Edit Claude Desktop's config file (creating it if it doesn't exist):

* macOS: `~/Library/Application Support/Claude/claude_desktop_config.json`
* Windows: `%APPDATA%\Claude\claude_desktop_config.json`

Add a server entry under `mcpServers`. Using the recommended archive install:

```json
{
  "mcpServers": {
    "localize": {
      "command": "/Users/<you>/.mix/escripts/localize_mcp"
    }
  }
}
```

Restart Claude Desktop fully (quit, don't just close the window). On startup Claude will spawn the server, run the MCP `initialize` handshake, and surface eleven new tools in the host's tool list.

If you'd rather invoke via `mix` (so the agent sees whichever Localize version your current project pins), use the alternate shape:

```json
{
  "mcpServers": {
    "localize": {
      "command": "mix",
      "args": ["localize_mcp"],
      "cwd": "/Users/<you>/dev/some_project_with_localize"
    }
  }
}
```

The `cwd` is required so `mix` finds the `mix.exs` that pins `:localize_mcp`. The agent then sees exactly the Localize / Calendrical / localize_web versions that project depends on.

## Wiring into Claude Code

Claude Code reads MCP config from `~/.claude/settings.json` (global) or `.claude/settings.json` (project-local). Either:

```json
{
  "mcpServers": {
    "localize": {
      "command": "/Users/<you>/.mix/escripts/localize_mcp"
    }
  }
}
```

Project-local config is useful when different projects want different Localize versions surfaced.

## Wiring into Zed

Zed reads MCP context servers from its main settings file. Add under `context_servers`:

```json
{
  "context_servers": {
    "localize": {
      "command": {
        "path": "/Users/<you>/.mix/escripts/localize_mcp",
        "args": []
      }
    }
  }
}
```

## Verifying

Three-step smoke test inside any chat with the host:

1. *"Use `localize_search` to find functions that format currencies."* — should return a ranked list including `Localize.Number.to_string/2` and `Localize.Currency.display_name/2`.
2. *"Use `localize_doc` on `Localize.Number.to_string` arity 2."* — should return the function's full `@doc` and `@spec`.
3. *"Use `localize_invoke` to format 1234 as USD with `Localize.Number.to_string/2`."* — should return `{:ok, "$1,234.00"}` encoded via the term grammar.

If step 1 fails, the server isn't being launched. Check the host's MCP log:

* Claude Desktop, macOS: `~/Library/Logs/Claude/mcp.log`
* Claude Desktop, Windows: `%APPDATA%\Claude\logs\mcp.log`
* Claude Code: `~/.claude/logs/mcp.log`

The most common failure is a wrong absolute path on the `command` field, followed by Elixir not being on `PATH` when the host launches the binary.

## The eleven tools

### Discovery (use these first when you don't know the API)

**`localize_search`** — keyword search across modules, functions, and docs.

```json
{ "query": "format currency", "kind": "function", "limit": 5 }
```

Returns ranked matches with one-line summaries. `kind` is optional; useful values: `"module"`, `"function"`, `"type"`, `"callback"`.

**`localize_browse`** — list every module in a documentation group.

```json
{ "group": "Numbers" }
```

Known groups: `Protocols`, `Numbers`, `Dates and Times`, `Locale`, `Language Tag`, `Calendars`, `Currencies`, `Languages`, `Territories`, `Scripts`, `Units of Measure`, `Messages`, `Gettext`, `Lists`, `Collation`, `Utilities`, `NIF`, `Exceptions`, `Web` (when `localize_web` is loaded).

### Documentation

**`localize_doc`** — full `@doc` + `@spec` for a module or function.

```json
{ "module": "Localize.Number", "function": "to_string", "arity": 2 }
```

With only `module`, returns the moduledoc plus a one-line summary of every public function. With `function` + `arity`, returns the per-function doc, signature, spec, and `:since` / `:deprecated` metadata.

**`localize_examples`** — curated example snippets keyed by capability.

```json
{ "capability": "format_number" }
```

Two families of capabilities:

* **Per-domain formatting**: `format_number`, `format_date`, `format_time`, `format_datetime`, `format_currency`, `format_unit`, `format_duration`, `format_interval`, `format_message`, `format_list`, `collate`, `parse_locale`, `parse_currency`, `parse_number`. Each entry typically has a `title`, a literal `code` snippet, and the `expected_output`.

* **Translation patterns**: `translate` (overview + pointers), `translate_setup` (Gettext backend, `~t` opt-in, PO file layout), `translate_headless` (no Phoenix — modules, CLIs, libraries), `translate_phoenix` (MVC controllers, HEEx templates, locale-detection plug, markup component, localized routes), `translate_liveview` (`on_mount` locale, locale switcher, pluralisation, PubSub-driven re-render). Entries may include `prose` (markdown explanation), `filename` (target file path for setup snippets), `code`, and `expected_output` — any field that doesn't apply is omitted.

When an agent says "help me set up translations", the right opener is `localize_examples capability=translate` — it returns an orientation document plus pointers to the framework-specific capability.

### Schema / contracts

**`localize_options`** — accepted options for a formatter function.

```json
{ "module": "Localize.Number", "function": "to_string", "arity": 2 }
```

Returns each accepted option with its type, allowed values (where the option is a closed atom set), default, and description. Use this *before* calling a function with options so you don't have to guess key names.

**`localize_atoms`** — closed atom collections.

```json
{ "collection": "currencies" }
```

Known collections: `locales`, `calendars`, `currencies`, `languages`, `scripts`, `territories`, `number_systems`, `measurement_systems`, `units`, `unit_categories`, `unit_usages`, `plural_categories`. Returns the canonical atom form (`:USD`, not `:usd`; `:"en-AU"`, not `:en_au`) so agents stop guessing case and separator.

**`localize_errors`** — every `Localize.*Error` exception module with its struct fields and (where the module adopts the `Localize.Exception` behaviour) the exhaustive list of documented `:reason` atoms.

```json
{ "module": "Localize.FormatError" }
```

Without `module`, returns every Localize error type. Use this when writing structured error handling — you'll see exactly what `:reason` values the caller can match.

### Resolution

**`localize_resolve_locale`** — show every stage Localize takes to canonicalise a locale input.

```json
{ "input": "en-AU" }
```

Returns parse result, validate result, `cldr_locale_id`, parent chain, `:supported_locales` membership, and whether the atom is interned at runtime. This is the single highest-value tool when you're not sure if `"en_au"` / `"en-AU"` / `:"en-AU"` is the right form.

**`localize_validate`** — kind-aware binary-input validator.

```json
{ "kind": "currency", "value": "USD" }
```

Returns `{kind, input, valid?, canonical, error?}`. Kinds: `currency`, `calendar`, `territory`, `script`, `number_system`, `language`, `locale`.

### Live invocation

**`localize_invoke`** — execute an allowlisted MFA.

```json
{
  "mfa": "Localize.Number.to_string/2",
  "args": [
    1234,
    { "$keyword": [
      ["format", { "$atom": "currency" }],
      ["currency", { "$atom": "USD" }],
      ["locale", { "$atom": "de" }]
    ] }
  ]
}
```

The allowlist is enumerated in `priv/mcp/invocable.exs` — currently 52 read-only functions covering formatting, parsing, validation, and display-name lookups. Anything not allowlisted returns `not_invokable`. Each call runs in a `Task.async/1` with a 5 second timeout and an 8 MiB heap cap.

**`localize_term_grammar`** — the JSON ↔ Elixir term grammar used by `localize_invoke`.

```json
{}
```

Returns the full reference: pass-through types, tagged forms (`$atom`, `$date`, `$time`, `$datetime`, `$naive_datetime`, `$decimal`, `$tuple`, `$keyword`, `$struct`), and the 16 KB input cap. Call this once per session if you need to encode atoms, dates, decimals, tuples, keyword lists, or structs as arguments.

## Translating messages

The MCP server has first-class support for surfacing Localize's translation pipeline — the `~t` sigil from `Localize.Message.Sigils`, the `Localize.Gettext.Interpolation` backend module, and the `Localize.HTML.Message` Phoenix component. An agent's typical translation-setup flow is three tool calls:

1. **`localize_examples capability=translate`** — orientation. Returns the overview plus pointers to the framework-specific capability.
2. **`localize_examples capability=translate_setup`** — five-step setup. mix.exs deps, Gettext backend module, PO directory layout, opting modules in to `~t`, setting the per-process locale.
3. **`localize_examples capability=translate_phoenix`** (or `translate_liveview`, or `translate_headless`) — framework-specific patterns. Locale-detection plug, on_mount callback, locale switcher, markup-aware rendering.

The underlying API the agent's code lands on:

| Surface | Use it for |
|---|---|
| `~t"Hello, #{name}!"` | The default. Compile-time MF2 + Gettext lookup with auto-derived bindings. |
| `~M"..."` | A static MF2 message that should *not* be translated — seed data, fixtures, format strings. |
| `Localize.Message.format/3` | Runtime msgid (loaded from DB / CMS / computed). Bypasses Gettext lookup. |
| `Localize.HTML.Message` | Phoenix component. Renders MF2 with markup tags (`{#bold}…{/bold}`, `{#link href=|/x|}…{/link}`) as HEEx. |
| `Localize.Plug.PutLocale` | Phoenix request-locale detection from query, path, session, Accept-Language, cookie, host TLD. |
| `Localize.Plug` (`on_mount` callback) | LiveView locale propagation from session into the LV process. |
| `Localize.Routes` | Compile-time path-segment translation (Gettext-driven). |
| `Localize.HTML.Locale.select/3` | A `<select>` for the locale switcher, with display-name-localised options. |

The agent doesn't need to know these names up-front — the `translate_*` example capabilities walk through each one in context.

## Optional integrations

The server detects `Calendrical` and `localize_web` at boot via `Code.ensure_loaded?/1`. When either is present:

* **Calendrical** adds non-Gregorian calendar atoms (`:japanese`, `:hebrew`, `:islamic`, `:persian`, …) to `localize_atoms collection=calendars`, surfaces `Calendrical.*` modules in `localize_search` / `localize_browse`, and accepts Calendrical date types in `localize_invoke` arguments.
* **localize_web** adds a new `"Web"` group to `localize_browse`, surfaces the Phoenix / Plug helpers in `localize_search`, and (in a later release) extends the invocation allowlist to read-only request-locale helpers.

To pin them, declare in your project's `mix.exs`:

```elixir
def deps do
  [
    {:localize_mcp, "~> 0.1", only: :dev},
    {:calendrical, "~> 0.1", only: :dev, optional: true},
    {:localize_web, "~> 0.1", only: :dev, optional: true}
  ]
end
```

The server runs identically with neither, either, or both present.

## Troubleshooting

**The host doesn't list any `localize_*` tools.** The server isn't being launched. Check the MCP log for spawn errors. The most common cause is the `command` path pointing at a binary that doesn't exist or isn't executable. `chmod +x` the escript if needed.

**`localize_invoke` returns `not_invokable` for a function I know exists.** The MFA isn't on the allowlist in `priv/mcp/invocable.exs`. The allowlist is deliberately read-only; mutating helpers, NIF entry points, and Mix tasks are excluded. File an issue (or a PR) if the function should be invokable.

**`localize_invoke` returns `{"error": {"kind": "exception", "module": "ArgumentError", "message": "not an already existing atom"}}`.** The agent passed an atom via the term grammar (`{"$atom": "foo"}`) but `:foo` isn't interned at runtime. Localize's atom-DOS hardening refuses to grow the atom table on caller input. Use the canonical form returned by `localize_validate` or `localize_atoms`.

**Tools work but answers feel stale.** The server's index is built once at boot. If you've hot-loaded a new Localize version into the running BEAM (unusual), restart the host to rebuild the index. For normal use this never matters — the agent restarts the server every session.

**The server seems slow.** The first tool call after boot pays for `Code.fetch_docs/1` over every Localize module; that's typically under 100 ms. Subsequent calls hit `:persistent_term` and complete in under 1 ms. If you're seeing higher numbers, check that `LocalizeMcp.Index` started cleanly (the supervisor log line says "Started Localize MCP" at info level).

## Reading further

* `guides/host_configuration.md` — focused reference for each AI host's config schema.
* `priv/mcp/invocable.exs` — the full allowlist of invokable MFAs.
* `priv/mcp/examples/` — the curated example library, one file per capability.
* `priv/mcp/options/` — the per-module options metadata. Currently `Localize.Number` is curated; more modules are added each release.

# Host configuration

How to wire `localize_mcp` into Claude Desktop, Claude Code, and Zed.

## Choosing a launch shape

Three options, in increasing order of "set up once, forget":

1. **`mix localize_mcp`** — run from inside an Elixir project that has `localize_mcp` as a dep. Works for one-off use; not great for AI hosts that launch the server per session.
2. **`./localize_mcp` escript** — the standalone binary built via `mix escript.build`. One file, no project required. Good for dropping into a `~/bin/` directory.
3. **`mix archive.install hex localize_mcp`** — the recommended path. Installs system-wide; invoke as `~/.mix/escripts/localize_mcp`. Survives Elixir version bumps via `asdf`/`mise`.

## Claude Desktop

`~/Library/Application Support/Claude/claude_desktop_config.json` on macOS, `%APPDATA%\Claude\claude_desktop_config.json` on Windows.

### Via the installed archive (recommended)

```json
{
  "mcpServers": {
    "localize": {
      "command": "/Users/<you>/.mix/escripts/localize_mcp"
    }
  }
}
```

### Via `mix` in a project directory

```json
{
  "mcpServers": {
    "localize": {
      "command": "mix",
      "args": ["localize_mcp"],
      "cwd": "/Users/<you>/dev/some_localize_project"
    }
  }
}
```

The `cwd` is required so `mix` finds the `mix.exs` that pins `:localize_mcp`. If your project pins a specific Localize version, that version's docs / atoms / examples are what the agent sees.

## Claude Code

`~/.claude/settings.json` (or a project-local `.claude/settings.json`):

```json
{
  "mcpServers": {
    "localize": {
      "command": "/Users/<you>/.mix/escripts/localize_mcp"
    }
  }
}
```

## Zed

Zed reads MCP config from your settings file. Add under `context_servers`:

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

After restarting the host, the eleven `localize_*` tools should be discoverable in the host's tool list. A round-trip smoke test:

1. Ask the agent: *"Use localize_search to find functions that format currencies."*
2. Then: *"Use localize_doc on Localize.Number.to_string/2."*
3. Then: *"Use localize_invoke to format 1234 as USD."*

If step 1 fails, the server isn't being launched. Check the host's MCP log (`~/Library/Logs/Claude/mcp.log` on macOS Claude Desktop) — the most common failure is a wrong absolute path on the `command` field.

## Calendrical / localize_web integration

When the host project (or the archive's compile environment) has `:calendrical` and/or `:localize_web` loaded, additional surface lights up:

* `localize_search` and `localize_browse` start returning `Calendrical.*` and `LocalizeWeb.*` modules.
* `localize_atoms` with `collection: "calendars"` includes Calendrical-specific calendars.
* The `localize_invoke` allowlist extends to read-only `LocalizeWeb` helpers.

To pin them, add to your project's `mix.exs`:

```elixir
def deps do
  [
    {:localize_mcp, "~> 0.1", only: :dev},
    {:calendrical, "~> 0.1", only: :dev, optional: true},
    {:localize_web, "~> 0.1", only: :dev, optional: true}
  ]
end
```

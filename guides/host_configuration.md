# Host configuration

How to wire `localize_mcp` into Claude Code, Claude Desktop, Codex CLI, ChatGPT, and Zed.

## Before you start

The server runs from an Elixir project that declares the dependency, so the agent sees exactly the Localize / Calendrical / localize_web versions that project pins:

```elixir
def deps do
  [
    {:localize_mcp, "~> 0.1", only: :dev}
  ]
end
```

Two things every host setup shares:

1. **Compile first.** Run `mix deps.get && mix compile` once before wiring the host. If the project needs compiling when the host launches the server, Mix prints compiler output on stdout, which is the MCP protocol channel.

2. **PATH for GUI hosts.** Hosts launched from the desktop (Claude Desktop, Zed) do not inherit your shell's `mise`/`asdf` activation. Launch via `sh -lc "…"` so a login shell resolves `mix`, or use an absolute path to the `mix` binary.

## Claude Code

From inside the project directory, one command:

```sh
claude mcp add localize -- mix localize_mcp
```

This registers a project-scoped stdio server; Claude Code launches it from the project directory, so `mix` finds the right `mix.exs`. To share the config with your team instead, commit a `.mcp.json` at the project root:

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

Verify with `claude mcp list` (or `/mcp` inside a session) — the server should show as connected with eleven `localize_*` tools.

## Claude Desktop

Claude Desktop has no per-project working directory, so change into the project explicitly. Edit `~/Library/Application Support/Claude/claude_desktop_config.json` on macOS (`%APPDATA%\Claude\claude_desktop_config.json` on Windows):

```json
{
  "mcpServers": {
    "localize": {
      "command": "sh",
      "args": ["-lc", "cd /Users/<you>/dev/my_localize_project && mix localize_mcp"]
    }
  }
}
```

Restart Claude Desktop fully (quit, don't just close the window). The `-l` flag makes `sh` a login shell so `mix` resolves through your version manager.

## Codex CLI

Codex supports local stdio MCP servers. Either register from the command line:

```sh
codex mcp add localize -- sh -lc "cd /Users/<you>/dev/my_localize_project && mix localize_mcp"
```

or add the equivalent to `~/.codex/config.toml`:

```toml
[mcp_servers.localize]
command = "sh"
args = ["-lc", "cd /Users/<you>/dev/my_localize_project && mix localize_mcp"]
```

Codex discovers the eleven `localize_*` tools on the next session.

## ChatGPT

ChatGPT's connectors (Settings → Connectors, with developer mode enabled) only attach to *remote* MCP servers reachable over HTTPS — they cannot launch a local stdio process. Two options:

* **Use Codex CLI** (above) for local development work — it shares ChatGPT models and supports local stdio servers directly. This is the recommended path.
* **Expose the server remotely.** `localize_mcp` ships stdio as its supported transport; if you need a remote endpoint you can put the server behind an HTTPS tunnel or reverse proxy, but that setup (authentication included) is yours to operate and is not covered here.

## Zed

Zed reads MCP servers from its settings file under `context_servers`:

```json
{
  "context_servers": {
    "localize": {
      "command": {
        "path": "sh",
        "args": ["-lc", "cd /Users/<you>/dev/my_localize_project && mix localize_mcp"]
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

If step 1 fails, the server isn't being launched. Check the host's MCP log (`~/Library/Logs/Claude/mcp*.log` for Claude Desktop on macOS; `claude mcp list` for Claude Code) — the most common failures are `mix` not resolving on the host's PATH and the project not being compiled yet.

## Calendrical / localize_web integration

When the host project has `:calendrical` and/or `:localize_web` compiled in, additional surface lights up:

* `localize_search` and `localize_browse` start returning `Calendrical.*` and `LocalizeWeb.*` modules.
* `localize_atoms` with `collection: "calendars"` includes Calendrical-specific calendars.

To pin them, add to your project's `mix.exs`:

```elixir
def deps do
  [
    {:localize_mcp, "~> 0.1", only: :dev},
    {:calendrical, "~> 0.1", only: :dev},
    {:localize_web, "~> 0.1", only: :dev}
  ]
end
```

defmodule Mix.Tasks.LocalizeMcp do
  @shortdoc "Starts the Localize MCP server on stdio"

  @moduledoc """
  Starts the Localize MCP server on stdio, the transport Claude
  Desktop / Claude Code / Zed use by default.

  ## Usage

      mix localize_mcp

  Logs go to stderr; JSON-RPC frames go on stdin/stdout. The task
  blocks until the OS process is killed.

  ## Host configuration

  See the [Host configuration guide](https://hexdocs.pm/localize_mcp/host_configuration.html) for Claude Code, Claude Desktop, Codex CLI, ChatGPT, and Zed. The Claude Code one-liner, run inside the project directory:

      claude mcp add localize -- mix localize_mcp

  Hosts without a per-project working directory launch via a login shell: `sh -lc "cd /path/to/project && mix localize_mcp"`.

  """

  use Mix.Task

  @requirements ["app.config"]

  @impl Mix.Task
  def run(_args) do
    # Stdout belongs to the MCP stdio protocol; move all logging to
    # stderr BEFORE the applications boot so dependency start-up
    # logs land there too.
    LocalizeMcp.Logging.redirect_to_stderr()
    Mix.Task.run("app.start")

    # Block until the OS process exits so the stdio server keeps
    # receiving frames.
    Process.sleep(:infinity)
  end
end

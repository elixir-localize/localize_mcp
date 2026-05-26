defmodule Mix.Tasks.LocalizeMcp do
  @shortdoc "Starts the Localize MCP server on stdio"

  @moduledoc """
  Starts the Localize MCP server on stdio, the transport Claude
  Desktop / Claude Code / Zed use by default.

  ## Usage

      mix localize_mcp

  Logs go to stderr; JSON-RPC frames go on stdin/stdout. The task
  blocks until the OS process is killed.

  ## Configuration

  Override the transport via `LOCALIZE_MCP_TRANSPORT`:

      LOCALIZE_MCP_TRANSPORT=streamable_http mix localize_mcp

  or in `config.exs`:

      config :localize_mcp, transport: :streamable_http

  ## Claude Desktop config snippet

      {
        "mcpServers": {
          "localize": {
            "command": "mix",
            "args": ["localize_mcp"]
          }
        }
      }

  """

  use Mix.Task

  @requirements ["app.start"]

  @impl Mix.Task
  def run(_args) do
    # The supervision tree (LocalizeMcp.Application) is already
    # started by `app.start`. Block until the OS process exits so
    # the stdio server keeps receiving frames.
    Process.sleep(:infinity)
  end
end

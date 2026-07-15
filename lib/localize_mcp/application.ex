defmodule LocalizeMcp.Application do
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children =
      [
        # Build the documentation / search index once at boot. The
        # tool handlers read from it via `:persistent_term` so
        # per-call cost is a single map lookup. The Anubis server
        # supervisor (started below) manages its own registry.
        LocalizeMcp.Index
      ] ++ maybe_server_child()

    options = [strategy: :one_for_one, name: LocalizeMcp.Supervisor]
    Supervisor.start_link(children, options)
  end

  # The stdio server child. Skipped when `:start_server` is `false`
  # (the test environment) so unit tests exercising tool handlers
  # don't compete for stdin with the test runner.
  defp maybe_server_child do
    if Application.get_env(:localize_mcp, :start_server, true) do
      [{LocalizeMcp.Server, transport: transport()}]
    else
      []
    end
  end

  # Defaults to stdio (what Claude Desktop / Code / Zed expect).
  # Override via `config :localize_mcp, transport: :streamable_http`
  # or by setting `LOCALIZE_MCP_TRANSPORT=streamable_http` in the
  # environment.
  defp transport do
    case Application.get_env(:localize_mcp, :transport, default_transport()) do
      :stdio -> :stdio
      :streamable_http -> :streamable_http
      :sse -> :sse
      other -> raise "Unknown :localize_mcp transport #{inspect(other)}"
    end
  end

  defp default_transport do
    case System.get_env("LOCALIZE_MCP_TRANSPORT") do
      nil -> :stdio
      "stdio" -> :stdio
      "streamable_http" -> :streamable_http
      "sse" -> :sse
      other -> raise "Unknown LOCALIZE_MCP_TRANSPORT=#{inspect(other)}"
    end
  end
end

defmodule LocalizeMcp.CLI do
  @moduledoc """
  Entry point for the standalone escript build of the server.

  Built via `mix escript.build`; the resulting `./localize_mcp`
  binary is identical in behaviour to `mix localize_mcp` but does
  not require a Mix project in the calling directory. This is the
  shape Claude Desktop / Code / Zed configurations typically expect
  when not using `mix archive.install`.

  """

  @doc false
  def main(_args) do
    {:ok, _started} = Application.ensure_all_started(:localize_mcp)
    Process.sleep(:infinity)
  end
end

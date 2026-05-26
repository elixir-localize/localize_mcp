defmodule LocalizeMcp do
  @moduledoc """
  Top-level entry point for the Localize MCP server.

  The interesting code lives in `LocalizeMcp.Server` (Hermes-MCP server
  with tool handlers) and the per-tool modules under
  `LocalizeMcp.Tools.*`. This module exists primarily as the
  documented public surface and as a place to hang version / boot
  helpers.

  See `README.md` for installation instructions and the full tool
  surface, and `plans/mcp_server.md` in the `localize` repo for the
  design rationale.

  """

  @doc """
  Returns the package version.

  Pulled from the application spec rather than hard-coded so the
  value stays in sync with `mix.exs`.

  """
  @spec version() :: String.t()
  def version do
    Application.spec(:localize_mcp, :vsn) |> to_string()
  end

  @doc """
  Returns whether the optional `Calendrical` package is loaded.

  Used by the server to decide whether to expose Calendrical-specific
  modules in search / browse / atoms results.

  """
  @spec calendrical_loaded?() :: boolean()
  def calendrical_loaded?, do: Code.ensure_loaded?(Calendrical)

  @doc """
  Returns whether the optional `localize_web` package is loaded.

  Used by the server to decide whether to expose `LocalizeWeb.*`
  modules in search / browse / atoms results.

  """
  @spec localize_web_loaded?() :: boolean()
  def localize_web_loaded?, do: Code.ensure_loaded?(LocalizeWeb)
end

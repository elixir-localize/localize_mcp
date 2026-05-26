defmodule LocalizeMcp.MixProject do
  use Mix.Project

  @version "0.1.0"
  @source_url "https://github.com/elixir-localize/localize_mcp"

  def project do
    [
      app: :localize_mcp,
      version: @version,
      elixir: "~> 1.17",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      description: description(),
      package: package(),
      docs: docs(),
      name: "Localize MCP",
      source_url: @source_url,
      escript: escript(),
      aliases: aliases(),
      dialyzer: [
        plt_add_apps: ~w(mix)a,
        flags: [
          :error_handling,
          :unknown,
          :underspecs,
          :extra_return,
          :missing_return
        ]
      ]
    ]
  end

  def application do
    [
      mod: {LocalizeMcp.Application, []},
      extra_applications: [:logger]
    ]
  end

  defp description do
    "Model Context Protocol (MCP) server for the Localize " <>
      "internationalisation library and its optional companions " <>
      "Calendrical and localize_web. Exposes structured tools for " <>
      "AI agents to discover and use the API without grep."
  end

  defp package do
    [
      maintainers: ["Kip Cole"],
      licenses: ["Apache-2.0"],
      links: %{
        "GitHub" => @source_url,
        "Changelog" => @source_url <> "/blob/v#{@version}/CHANGELOG.md"
      },
      files: [
        "lib",
        "mix.exs",
        "README*",
        "CHANGELOG*",
        "LICENSE*",
        "config",
        "priv/mcp",
        "guides"
      ]
    ]
  end

  defp docs do
    [
      source_ref: "v#{@version}",
      main: "readme",
      extras: [
        "README.md",
        "guides/usage.md",
        "guides/host_configuration.md",
        "CHANGELOG.md",
        "LICENSE.md"
      ],
      formatters: ["html"]
    ]
  end

  defp deps do
    [
      # The library being introspected. Required.
      {:localize, "~> 0.38"},

      # Optional companions. Detected at runtime via Code.ensure_loaded?/1;
      # the server runs identically with neither, either, or both.
      {:calendrical, "~> 0.1", optional: true},
      {:localize_web, "~> 0.1", optional: true},

      # MCP transport + tool dispatch.
      {:hermes_mcp, "~> 0.10"},

      # Dev / docs / test.
      {:ex_doc, "~> 0.30", only: :dev, runtime: false},
      {:dialyxir, "~> 1.4", only: :dev, runtime: false}
    ]
  end

  # `mix localize_mcp` boots the stdio server for use under Claude
  # Desktop / Claude Code / Zed configurations. The escript form
  # below is the same entry point bundled as a standalone binary
  # via `mix escript.build`, useful when users want a single file
  # to drop into their PATH.
  defp escript do
    [
      main_module: LocalizeMcp.CLI,
      name: "localize_mcp"
    ]
  end

  defp aliases do
    [
      # Convenience: `mix localize_mcp` (the Mix task) runs the server
      # without first building an escript. See lib/mix/tasks/localize_mcp.ex.
      "localize_mcp.archive": ["archive.build"]
    ]
  end
end

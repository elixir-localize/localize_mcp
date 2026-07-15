defmodule LocalizeMcp.MixProject do
  use Mix.Project

  @version "0.1.0"
  @source_url "https://github.com/elixir-localize/localize_mcp"

  def project do
    [
      app: :localize_mcp,
      version: @version,
      # anubis_mcp requires Elixir 1.18+ (it uses the JSON.Encoder
      # protocol), so the floor cannot follow localize down to 1.17.
      elixir: "~> 1.18",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      description: description(),
      package: package(),
      docs: docs(),
      name: "Localize MCP",
      source_url: @source_url,
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
        "Readme" => "https://hexdocs.pm/localize_mcp/readme.html",
        "Changelog" => "https://hexdocs.pm/localize_mcp/changelog.html"
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
      # The library being introspected. Required. The floor tracks
      # recent Localize releases because the tools introspect the
      # current module layout, docs groups and options surface.
      {:localize, "~> 0.49"},

      # Optional companions. Detected at runtime via Code.ensure_loaded?/1;
      # the server runs identically with neither, either, or both.
      {:calendrical, "~> 0.1", optional: true},
      {:localize_web, "~> 0.1", optional: true},

      # MCP transport + tool dispatch. Anubis is the continuation of
      # the renamed hermes_mcp project; hermes_mcp 0.14.x is
      # unmaintained and its stdio transport cannot decode frames.
      {:anubis_mcp, "~> 1.6"},

      # Dev / docs / test. ex_doc is available in :release so docs
      # build in the same environment they are published from.
      {:ex_doc, "~> 0.30", only: [:dev, :release], runtime: false},
      {:dialyxir, "~> 1.4", only: :dev, runtime: false}
    ] ++ maybe_json_polyfill()
  end

  # Localize uses the OTP 27+ `:json` module. On OTP 26 the
  # json_polyfill package provides it; consumers on OTP 26 add
  # {:json_polyfill, "~> 0.2 or ~> 1.0"} to their own deps (see the
  # Localize README). This dev/test conditional keeps this project's
  # own CI compiling on OTP 26 and is scheduled for removal when
  # Localize drops OTP 26 support on December 31st, 2026.
  defp maybe_json_polyfill do
    if Code.ensure_loaded?(:json) do
      []
    else
      [{:json_polyfill, "~> 0.2 or ~> 1.0", only: [:dev, :test]}]
    end
  end
end

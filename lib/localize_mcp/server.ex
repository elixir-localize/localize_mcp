defmodule LocalizeMcp.Server do
  @moduledoc """
  The Anubis-MCP server for Localize.

  Tools are registered in `init/2` and dispatched via `handle_tool/3`.
  Each tool's implementation lives in `LocalizeMcp.Tools.<Name>` so
  this module stays a thin router; per-tool behaviour, validation,
  and tests live alongside the implementation.

  """

  use Anubis.Server,
    name: "Localize MCP",
    version: "0.1.0",
    capabilities: [:tools]

  alias Anubis.Server.Response
  alias LocalizeMcp.Tools

  @impl true
  def init(_client_info, frame) do
    frame =
      frame
      |> register_search_tool()
      |> register_browse_tool()
      |> register_doc_tool()
      |> register_examples_tool()
      |> register_options_tool()
      |> register_atoms_tool()
      |> register_errors_tool()
      |> register_resolve_locale_tool()
      |> register_validate_tool()
      |> register_invoke_tool()
      |> register_term_grammar_tool()

    {:ok, frame}
  end

  @impl true
  def handle_tool_call("localize_search", params, frame) do
    reply(Tools.Search.call(string_keyed(params)), frame)
  end

  def handle_tool_call("localize_browse", params, frame) do
    reply(Tools.Browse.call(string_keyed(params)), frame)
  end

  def handle_tool_call("localize_doc", params, frame) do
    reply(Tools.Doc.call(string_keyed(params)), frame)
  end

  def handle_tool_call("localize_examples", params, frame) do
    reply(Tools.Examples.call(string_keyed(params)), frame)
  end

  def handle_tool_call("localize_options", params, frame) do
    reply(Tools.Options.call(string_keyed(params)), frame)
  end

  def handle_tool_call("localize_atoms", params, frame) do
    reply(Tools.Atoms.call(string_keyed(params)), frame)
  end

  def handle_tool_call("localize_errors", params, frame) do
    reply(Tools.Errors.call(string_keyed(params)), frame)
  end

  def handle_tool_call("localize_resolve_locale", params, frame) do
    reply(Tools.ResolveLocale.call(string_keyed(params)), frame)
  end

  def handle_tool_call("localize_validate", params, frame) do
    reply(Tools.Validate.call(string_keyed(params)), frame)
  end

  def handle_tool_call("localize_invoke", params, frame) do
    reply(Tools.Invoke.call(string_keyed(params)), frame)
  end

  def handle_tool_call("localize_term_grammar", params, frame) do
    reply(Tools.TermGrammar.call(string_keyed(params)), frame)
  end

  # Anubis validates tool arguments against the registered schema
  # (atomising the top-level keys) and expects an
  # `Anubis.Server.Response` back. The tool implementations keep
  # their original contract — string-keyed params in, a plain result
  # map out — so their unit tests stay transport-independent.
  defp reply(result, frame) do
    {:reply, Response.json(Response.tool(), result), frame}
  end

  defp string_keyed(params) do
    Map.new(params, fn {key, value} -> {to_string(key), value} end)
  end

  # ── Tool registration ─────────────────────────────────────────

  defp register_search_tool(frame) do
    register_tool(frame, "localize_search",
      description:
        "Keyword search across Localize (and Calendrical / localize_web when loaded) modules, " <>
          "functions, and docs. Returns ranked matches with one-line summaries. Use this when " <>
          "you don't know the exact module or function name.",
      input_schema: %{
        query:
          {:required, :string,
           description:
             "The search query. Matched against module names, function names, and doc first lines."},
        kind:
          {:string,
           description:
             "Restrict to a kind. One of \"module\", \"function\", \"type\", \"callback\"."},
        limit: {:integer, description: "Maximum results to return. Default 20."}
      },
      annotations: %{read_only: true}
    )
  end

  defp register_browse_tool(frame) do
    register_tool(frame, "localize_browse",
      description:
        "List the modules in a documentation group (e.g. \"Numbers\", \"Dates and Times\", " <>
          "\"Locale\"). Returns each module with its moduledoc first line. Use this when you " <>
          "want to scan everything in a domain.",
      input_schema: %{
        group:
          {:required, :string,
           description:
             "The group name. Known groups: Localize (the top-level module), Protocols, " <>
               "Numbers, Dates and Times, Locale, Language Tag, Calendars, Currencies, " <>
               "Languages, Territories, Scripts, Units of Measure, Messages, Gettext, " <>
               "Lists, Collation, NIF, Exceptions, Web (when localize_web is loaded)."}
      },
      annotations: %{read_only: true}
    )
  end

  defp register_doc_tool(frame) do
    register_tool(frame, "localize_doc",
      description:
        "Fetch the full @doc + @spec for a module or function. Returns moduledoc / funcdoc / " <>
          "spec / examples extracted from the compiled BEAM via Code.fetch_docs/1.",
      input_schema: %{
        module:
          {:required, :string,
           description:
             "The module name (with or without \"Elixir.\" prefix). E.g. \"Localize.Number\" or " <>
               "\"Elixir.Localize.Number\"."},
        function:
          {:string, description: "Optional function name to scope to a specific function."},
        arity: {:integer, description: "Optional arity to disambiguate overloaded functions."}
      },
      annotations: %{read_only: true}
    )
  end

  defp register_examples_tool(frame) do
    register_tool(frame, "localize_examples",
      description:
        "Curated example snippets for a given capability. Two families: per-domain " <>
          "formatting (format_number, format_date, format_currency, format_unit, …) and " <>
          "message translation (translate, translate_setup, translate_headless, " <>
          "translate_phoenix, translate_liveview). Translation examples cover the `~t` " <>
          "sigil, Gettext backend setup, locale-on-mount in LiveView, MF2 markup " <>
          "components, and locale-switcher patterns. Each example may include prose, a " <>
          "target filename, a code snippet, and (where applicable) the expected output.",
      input_schema: %{
        capability:
          {:required, :string,
           description:
             "The capability name. Formatting: format_number, format_date, format_time, " <>
               "format_datetime, format_currency, format_unit, format_duration, " <>
               "format_interval, format_message, format_list, collate, parse_locale, " <>
               "parse_currency, parse_number. Translation: translate (overview), " <>
               "translate_setup (Gettext backend + ~t opt-in), translate_headless (no " <>
               "Phoenix), translate_phoenix (MVC + plugs + markup component), " <>
               "translate_liveview (on_mount, locale switcher, PubSub)."}
      },
      annotations: %{read_only: true}
    )
  end

  defp register_options_tool(frame) do
    register_tool(frame, "localize_options",
      description:
        "For a formatter function, return its accepted options with types, allowed values, " <>
          "defaults, and one-line descriptions. Use this BEFORE calling a function with options " <>
          "to avoid guessing key names.",
      input_schema: %{
        module: {:required, :string, description: "The module name."},
        function: {:required, :string, description: "The function name."},
        arity: {:integer, description: "Optional arity to disambiguate."}
      },
      annotations: %{read_only: true}
    )
  end

  defp register_atoms_tool(frame) do
    register_tool(frame, "localize_atoms",
      description:
        "Return the closed atom collection for a named kind — locales, calendars, currencies, " <>
          "languages, scripts, territories, number_systems, measurement_systems, units, " <>
          "unit_categories, unit_usages, plural_categories. Use this to find the exact atom " <>
          "form CLDR expects (e.g. :USD not :usd, :\"en-AU\" not :en_au).",
      input_schema: %{
        collection: {:required, :string, description: "The collection name."}
      },
      annotations: %{read_only: true}
    )
  end

  defp register_errors_tool(frame) do
    register_tool(frame, "localize_errors",
      description:
        "List every Localize.*Error exception module with its struct fields and (where the " <>
          "module adopts Localize.Exception) the exhaustive list of documented :reason atoms. " <>
          "Use this when handling errors structurally.",
      input_schema: %{
        module: {:string, description: "Optional. Scope to one Localize.*Error module."}
      },
      annotations: %{read_only: true}
    )
  end

  defp register_resolve_locale_tool(frame) do
    register_tool(frame, "localize_resolve_locale",
      description:
        "Given a caller-supplied locale (atom or string), show every stage Localize takes to " <>
          "canonicalise it — parse, validate, resolve cldr_locale_id, walk the parent chain, " <>
          "check membership in :supported_locales. This is the single highest-value tool when " <>
          "you're not sure if 'en_au' / 'en-AU' / :\"en-AU\" is the right form.",
      input_schema: %{
        input:
          {:required, :string,
           description: "The locale input. e.g. \"en-AU\", \"pt_BR\", \"zh-Hant-HK\"."}
      },
      annotations: %{read_only: true}
    )
  end

  defp register_validate_tool(frame) do
    register_tool(frame, "localize_validate",
      description:
        "Kind-aware binary-input validator. Returns whether the input is accepted and what " <>
          "canonical atom it resolves to. Kinds: currency, calendar, territory, script, " <>
          "number_system, language, locale.",
      input_schema: %{
        kind:
          {:required, :string,
           description:
             "One of: currency, calendar, territory, script, number_system, language, locale."},
        value: {:required, :string, description: "The value to validate."}
      },
      annotations: %{read_only: true}
    )
  end

  defp register_invoke_tool(frame) do
    register_tool(frame, "localize_invoke",
      description:
        "Execute an allowlisted read-only Localize function and return the result. " <>
          "Arguments use the JSON ↔ Elixir term grammar — call `localize_term_grammar` for " <>
          "the reference. Allowlisted MFAs are enumerated in priv/mcp/invocable.exs; " <>
          "anything else returns `not_invokable`.",
      input_schema: %{
        mfa:
          {:required, :string,
           description: "The MFA to call, e.g. \"Localize.Number.to_string/2\"."},
        args:
          {:required, {:list, :any},
           description:
             "List of arguments. Each is a JSON term following the localize_term_grammar (use " <>
               "tagged objects like {\"$atom\":\"en\"} for atoms, etc.)."}
      },
      annotations: %{read_only: true}
    )
  end

  defp register_term_grammar_tool(frame) do
    register_tool(frame, "localize_term_grammar",
      description:
        "Returns the JSON ↔ Elixir term grammar used by `localize_invoke`. Call this once " <>
          "per session if you need to encode atoms, dates, decimals, tuples, keyword lists, " <>
          "or structs as arguments.",
      input_schema: %{},
      annotations: %{read_only: true}
    )
  end
end

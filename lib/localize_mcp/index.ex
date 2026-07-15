defmodule LocalizeMcp.Index do
  @moduledoc """
  Boot-time index of every documented module/function across
  `:localize`, `:calendrical`, and `:localize_web` (the latter two
  when loaded).

  Built once during application start and cached in
  `:persistent_term` so individual tool handlers pay only a map
  lookup per call. Rebuild explicitly with `rebuild/0` if a
  consumer hot-loads new modules at runtime — not the common case.

  Each entry has the shape:

      %{
        module: Localize.Number,
        function: :to_string,
        arity: 2,
        kind: :function,                   # or :module / :type / :callback
        signature: "to_string(number, options \\\\ [])",
        doc_first_line: "Format a number as a localized string.",
        group: "Numbers",
        package: :localize                  # or :calendrical / :localize_web
      }

  """

  use GenServer

  @persistent_term_key {:localize_mcp, :index}

  # ── Public API ─────────────────────────────────────────────────

  @doc """
  Starts the index GenServer.

  """
  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(options \\ []) do
    GenServer.start_link(__MODULE__, options, name: __MODULE__)
  end

  @doc """
  Returns the full list of indexed entries.

  Reads from `:persistent_term` — O(1) heap copy of the list.

  """
  @spec entries() :: [map()]
  def entries do
    case :persistent_term.get(@persistent_term_key, :not_built) do
      :not_built -> []
      entries -> entries
    end
  end

  @doc """
  Rebuilds the index from scratch. Cheap — runs in under 100 ms on
  typical hardware.

  """
  @spec rebuild() :: :ok
  def rebuild do
    GenServer.call(__MODULE__, :rebuild)
  end

  # ── GenServer callbacks ────────────────────────────────────────

  @impl true
  def init(_options) do
    :persistent_term.put(@persistent_term_key, build())
    {:ok, %{}}
  end

  @impl true
  def handle_call(:rebuild, _from, state) do
    :persistent_term.put(@persistent_term_key, build())
    {:reply, :ok, state}
  end

  # ── Index construction ─────────────────────────────────────────

  @doc false
  @spec build() :: [map()]
  def build do
    packages_to_index()
    |> Enum.flat_map(&entries_for_package/1)
    |> Enum.sort_by(fn entry ->
      {entry.module, entry.function || :__module__, entry.arity || 0}
    end)
  end

  defp packages_to_index do
    base = [{:localize, "Localize"}]

    optional =
      [
        {:calendrical, "Calendrical", LocalizeMcp.calendrical_loaded?()},
        {:localize_web, "LocalizeWeb", LocalizeMcp.localize_web_loaded?()}
      ]
      |> Enum.filter(fn {_, _, loaded?} -> loaded? end)
      |> Enum.map(fn {app, prefix, _} -> {app, prefix} end)

    base ++ optional
  end

  defp entries_for_package({app, prefix}) do
    case Application.spec(app, :modules) do
      modules when is_list(modules) ->
        modules
        |> Enum.filter(&module_in_prefix?(&1, prefix))
        |> Enum.flat_map(&entries_for_module(&1, app))

      _ ->
        []
    end
  end

  defp module_in_prefix?(module, prefix) do
    name = Atom.to_string(module)
    name == "Elixir.#{prefix}" or String.starts_with?(name, "Elixir.#{prefix}.")
  end

  defp entries_for_module(module, app) do
    case Code.fetch_docs(module) do
      # A hidden module (`@moduledoc false`) is internal API: its
      # functions are excluded too, so the tool surface matches the
      # documented surface.
      {:docs_v1, _, _, _, :hidden, _, _} ->
        []

      {:docs_v1, _, _, _, module_doc, _, function_docs} ->
        module_entry = module_entry(module, module_doc, app)
        function_entries = Enum.flat_map(function_docs, &function_entry(&1, module, app))
        [module_entry | function_entries] |> Enum.reject(&is_nil/1)

      _ ->
        []
    end
  end

  defp module_entry(_module, :none, _app), do: nil

  defp module_entry(module, %{} = doc_map, app) do
    %{
      module: module,
      function: nil,
      arity: nil,
      kind: :module,
      signature: inspect(module),
      doc_first_line: first_line(doc_map),
      doc_text: doc_excerpt(doc_map),
      group: group_for(module),
      package: app
    }
  end

  defp function_entry({{kind, name, arity}, _anno, signature, doc, _meta}, module, app)
       when kind in [:function, :macro, :callback, :type] do
    case doc do
      :hidden ->
        []

      _ ->
        [
          %{
            module: module,
            function: name,
            arity: arity,
            kind: kind,
            signature: Enum.join(signature, " "),
            doc_first_line: first_line(doc),
            doc_text: doc_excerpt(doc),
            group: group_for(module),
            package: app
          }
        ]
    end
  end

  defp function_entry(_, _, _), do: []

  defp first_line(%{"en" => doc}) when is_binary(doc) do
    doc
    |> String.split("\n", parts: 2)
    |> List.first()
    |> String.trim()
  end

  defp first_line(_), do: ""

  # A longer lowercased excerpt used by multi-word search matching
  # (long enough to reach a typical `### Options` section). The
  # first line remains the human-facing summary.
  defp doc_excerpt(%{"en" => doc}) when is_binary(doc) do
    doc
    |> String.slice(0, 2000)
    |> String.downcase()
  end

  defp doc_excerpt(_), do: ""

  # Lifted from `mix.exs`'s `groups_for_modules/0` in the upstream
  # `localize` repo. Kept in sync by hand — there's no public API to
  # read this from the compiled application.
  @groups [
    {~r/^Localize\.Chars(\.|$)/, "Protocols"},
    {~r/Localize\.Number/, "Numbers"},
    {~r/^Localize\.(Date|Time|Interval|Duration)(?!\w*Error)/, "Dates and Times"},
    {~r/Localize\.Locale(?!\w*Error)/, "Locale"},
    {~r/Localize\.(LanguageTag|Rfc5646)(?!\w*Error)/, "Language Tag"},
    {~r/Localize\.Calendar(?!\w*Error)/, "Calendars"},
    {~r/Localize\.Currency(?!\w*Error)/, "Currencies"},
    {~r/Localize\.Language(?!\w*Error)/, "Languages"},
    {~r/Localize\.Territory(?!\w*Error)/, "Territories"},
    {~r/Localize\.Script(?!\w*Error)/, "Scripts"},
    {~r/^Localize\.Unit?(?:\.|$)/, "Units of Measure"},
    {~r/Localize\.Message(?!\w*Error)/, "Messages"},
    {~r/Gettext(?!\w*Error)/, "Gettext"},
    {~r/Localize\.List(?!\w*Error)/, "Lists"},
    {~r/Localize\.Collation(?!\w*Error)/, "Collation"},
    {~r/Localize\.Nif(?!\w*Error)/, "NIF"},
    {~r/^Localize\.\w+Error$/, "Exceptions"},
    {~r/^Calendrical(\.|$)/, "Calendars"},
    {~r/^LocalizeWeb(\.|$)/, "Web"},
    # The bare top module carries the locale get/put/validate API.
    {~r/^Localize$/, "Localize"}
  ]

  defp group_for(module) do
    # Strip the "Elixir." prefix so the `^Localize\.…` and
    # `^Calendrical(\.|$)` anchors in @groups match. Without this
    # step every anchored regex misses because Erlang atom-to-string
    # of an Elixir module starts with `Elixir.`.
    name =
      case Atom.to_string(module) do
        "Elixir." <> rest -> rest
        other -> other
      end

    Enum.find_value(@groups, "Other", fn {regex, group} ->
      if Regex.match?(regex, name), do: group
    end)
  end
end

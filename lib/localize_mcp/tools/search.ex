defmodule LocalizeMcp.Tools.Search do
  @moduledoc """
  Implementation of the `localize_search` tool.

  Ranks index entries against the caller's query. Ranking is
  deliberately simple — exact name match > substring on name >
  substring on doc — because the index is small enough (~3000
  entries across all three packages) that anything fancier would
  spend more time than it saves.

  """

  alias LocalizeMcp.Index

  @default_limit 20
  @max_limit 200

  @spec call(map()) :: map()
  def call(%{"query" => query} = params) when is_binary(query) and query != "" do
    kind = parse_kind(params["kind"])
    limit = min(params["limit"] || @default_limit, @max_limit)
    normalized = String.downcase(query)

    matches =
      Index.entries()
      |> Enum.filter(&kind_matches?(&1, kind))
      |> Enum.map(&{score(&1, normalized), &1})
      |> Enum.reject(fn {score, _} -> score == 0 end)
      |> Enum.sort_by(fn {score, entry} -> {-score, entry.module, entry.function} end)
      |> Enum.take(limit)
      |> Enum.map(fn {_score, entry} -> render(entry) end)

    %{matches: matches, total: length(matches), query: query}
  end

  def call(_), do: %{error: "missing required parameter :query"}

  # ── Ranking ───────────────────────────────────────────────────

  defp score(entry, query) do
    name = entry_name(entry) |> String.downcase()
    doc = String.downcase(entry.doc_first_line || "")

    cond do
      name == query -> 100
      String.starts_with?(name, query) -> 80
      String.contains?(name, query) -> 60
      String.contains?(doc, query) -> 30
      true -> 0
    end
  end

  defp entry_name(%{function: nil, module: module}), do: inspect(module)

  defp entry_name(%{module: module, function: f, arity: a}) do
    "#{inspect(module)}.#{f}/#{a}"
  end

  # ── Filters / parsing ─────────────────────────────────────────

  defp parse_kind(nil), do: :any
  defp parse_kind("module"), do: :module
  defp parse_kind("function"), do: :function
  defp parse_kind("macro"), do: :macro
  defp parse_kind("type"), do: :type
  defp parse_kind("callback"), do: :callback
  defp parse_kind(_), do: :any

  defp kind_matches?(_entry, :any), do: true
  defp kind_matches?(%{kind: k}, k), do: true
  defp kind_matches?(_, _), do: false

  # ── Output rendering ──────────────────────────────────────────

  defp render(entry) do
    %{
      name: entry_name(entry),
      kind: Atom.to_string(entry.kind),
      group: entry.group,
      package: Atom.to_string(entry.package),
      summary: entry.doc_first_line
    }
  end
end

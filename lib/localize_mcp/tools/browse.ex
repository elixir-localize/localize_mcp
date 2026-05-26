defmodule LocalizeMcp.Tools.Browse do
  @moduledoc """
  Implementation of the `localize_browse` tool.

  Returns every module in the given documentation group with its
  moduledoc first line. Useful for scanning a whole domain — "what's
  in Numbers?" — rather than searching by keyword.

  """

  alias LocalizeMcp.Index

  @spec call(map()) :: map()
  def call(%{"group" => group}) when is_binary(group) do
    modules =
      Index.entries()
      |> Enum.filter(&(&1.kind == :module and &1.group == group))
      |> Enum.sort_by(& &1.module)
      |> Enum.map(&render/1)

    %{group: group, modules: modules, total: length(modules)}
  end

  def call(_), do: %{error: "missing required parameter :group"}

  defp render(%{module: module, doc_first_line: doc, package: package}) do
    %{
      module: inspect(module),
      package: Atom.to_string(package),
      summary: doc
    }
  end
end

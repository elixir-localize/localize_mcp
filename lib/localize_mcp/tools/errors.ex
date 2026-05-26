defmodule LocalizeMcp.Tools.Errors do
  @moduledoc """
  Implementation of the `localize_errors` tool.

  Returns every `Localize.*Error` exception module along with its
  struct fields and (where the module adopts `Localize.Exception`)
  the exhaustive list of documented `:reason` atoms.

  Backed by the `reason_atoms/0` callback on `Localize.Exception`,
  introduced in Localize 0.31.x specifically so tools like this
  one don't have to grep the source for atom literals.

  """

  @spec call(map()) :: map()
  def call(params \\ %{})

  def call(%{"module" => module_str}) when is_binary(module_str) do
    case resolve_error_module(module_str) do
      {:ok, module} ->
        %{modules: [describe(module)]}

      {:error, reason} ->
        %{error: reason}
    end
  end

  def call(_) do
    %{modules: Enum.map(error_modules(), &describe/1)}
  end

  # ── Discovery ────────────────────────────────────────────────

  defp error_modules do
    Application.spec(:localize, :modules)
    |> Enum.filter(&error_module?/1)
    |> Enum.sort()
  end

  defp error_module?(module) do
    name = Atom.to_string(module)
    String.starts_with?(name, "Elixir.Localize.") and String.ends_with?(name, "Error")
  end

  defp resolve_error_module("Elixir." <> _ = name) do
    atom = String.to_atom(name)

    if Code.ensure_loaded?(atom) and error_module?(atom),
      do: {:ok, atom},
      else: {:error, "module #{name} is not a Localize.*Error"}
  end

  defp resolve_error_module(name) when is_binary(name) do
    resolve_error_module("Elixir." <> name)
  end

  # ── Per-module description ───────────────────────────────────

  defp describe(module) do
    %{
      module: inspect(module),
      fields: struct_fields(module),
      reason_atoms: reason_atoms_for(module),
      moduledoc: moduledoc_first_line(module)
    }
  end

  defp struct_fields(module) do
    try do
      struct(module, [])
      |> Map.from_struct()
      |> Map.keys()
      |> Enum.sort()
      |> Enum.map(&Atom.to_string/1)
    rescue
      _ -> []
    end
  end

  defp reason_atoms_for(module) do
    if function_exported?(module, :reason_atoms, 0) do
      Enum.map(module.reason_atoms(), &inspect/1)
    else
      []
    end
  end

  defp moduledoc_first_line(module) do
    case Code.fetch_docs(module) do
      {:docs_v1, _, _, _, %{"en" => doc}, _, _} when is_binary(doc) ->
        doc |> String.split("\n", parts: 2) |> List.first() |> String.trim()

      _ ->
        ""
    end
  end
end

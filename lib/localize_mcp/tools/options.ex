defmodule LocalizeMcp.Tools.Options do
  @moduledoc """
  Implementation of the `localize_options` tool.

  Returns the accepted options for a formatter function with their
  types, allowed values, defaults, and descriptions. Backed by
  curated metadata files at `priv/mcp/options/<module>.exs` — each
  file evaluates to a map from `{function_name, arity}` to a list
  of option specs.

  Each option spec has the shape:

      %{
        name: :locale,
        type: "atom() | String.t() | Localize.LanguageTag.t()",
        allowed_values: nil,             # or a list of atoms / strings
        default: ":en",
        description: "The locale to format under."
      }

  When no metadata file exists for a module the tool returns the
  raw `@spec` lifted via `Code.fetch_docs/1` so the caller still
  gets a useful answer — just with `allowed_values: nil`
  everywhere. Manually curated entries take precedence.

  """

  @spec call(map()) :: map()
  def call(%{"module" => module_str, "function" => function_str} = params)
      when is_binary(module_str) and is_binary(function_str) do
    arity = params["arity"]

    with {:ok, module} <- resolve_module(module_str) do
      function_atom = String.to_atom(function_str)

      case load_metadata(module) do
        {:ok, metadata} ->
          resolve_options(module, function_atom, arity, metadata)

        {:error, :not_found} ->
          # Fall back to the raw @spec for un-curated modules.
          %{
            module: inspect(module),
            function: function_str,
            arity: arity,
            options: [],
            note:
              "No curated metadata file at priv/mcp/options/#{inspect(module)}.exs. " <>
                "Consult `localize_doc` for the @spec until curation lands."
          }
      end
    else
      {:error, reason} -> %{error: reason}
    end
  end

  def call(_),
    do: %{error: "required parameters: :module, :function (optional :arity)"}

  # ── Metadata loading ─────────────────────────────────────────

  defp load_metadata(module) do
    path = metadata_path(module)

    if File.exists?(path) do
      try do
        {metadata, _bindings} = Code.eval_file(path)
        {:ok, metadata}
      rescue
        exception -> {:error, exception}
      end
    else
      {:error, :not_found}
    end
  end

  defp metadata_path(module) do
    Application.app_dir(:localize_mcp, [
      "priv",
      "mcp",
      "options",
      "#{inspect(module)}.exs"
    ])
  end

  defp resolve_options(module, function_atom, arity, metadata) do
    candidates =
      metadata
      |> Enum.filter(fn {{name, a}, _opts} ->
        name == function_atom and (is_nil(arity) or a == arity)
      end)

    case candidates do
      [] ->
        %{
          module: inspect(module),
          function: Atom.to_string(function_atom),
          arity: arity,
          options: [],
          note: "No curated entry for #{inspect(module)}.#{function_atom}/#{arity || "_"}"
        }

      [{{_, a}, opts}] ->
        %{
          module: inspect(module),
          function: Atom.to_string(function_atom),
          arity: a,
          options: Enum.map(opts, &normalise_option/1)
        }

      many ->
        %{
          module: inspect(module),
          function: Atom.to_string(function_atom),
          arities: Enum.map(many, fn {{_, a}, _} -> a end),
          note: "Multiple arities curated; pass :arity to disambiguate."
        }
    end
  end

  defp normalise_option(%{name: _} = opt) do
    Map.merge(
      %{name: nil, type: nil, allowed_values: nil, default: nil, description: nil},
      opt
    )
  end

  defp normalise_option(other), do: %{error: "malformed option spec: #{inspect(other)}"}

  # ── Module resolution ────────────────────────────────────────

  defp resolve_module("Elixir." <> _ = name) do
    atom = String.to_atom(name)
    if Code.ensure_loaded?(atom), do: {:ok, atom}, else: {:error, "module #{name} not loaded"}
  end

  defp resolve_module(name), do: resolve_module("Elixir." <> name)
end

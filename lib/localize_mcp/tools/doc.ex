defmodule LocalizeMcp.Tools.Doc do
  @moduledoc """
  Implementation of the `localize_doc` tool.

  Pulls `@doc`, `@spec`, and signature info from the compiled BEAM
  via `Code.fetch_docs/1`. When called with just `module`, returns
  the moduledoc plus the list of public functions. When called with
  `module` + `function` (+ optional `arity`), returns the per-function
  documentation, spec, signature, and examples.

  """

  @spec call(map()) :: map()
  def call(%{"module" => module_str} = params) when is_binary(module_str) do
    case resolve_module(module_str) do
      {:ok, module} ->
        case Code.fetch_docs(module) do
          {:docs_v1, _anno, _lang, _format, module_doc, _meta, function_docs} ->
            render(module, module_doc, function_docs, params)

          {:error, reason} ->
            %{error: "Code.fetch_docs/1 failed: #{inspect(reason)}", module: inspect(module)}

          other ->
            %{error: "unexpected fetch_docs result: #{inspect(other)}", module: inspect(module)}
        end

      {:error, reason} ->
        %{error: reason, module: module_str}
    end
  end

  def call(_), do: %{error: "missing required parameter :module"}

  # ── Module resolution ─────────────────────────────────────────

  defp resolve_module("Elixir." <> _ = name) do
    atom = String.to_atom(name)
    if Code.ensure_loaded?(atom), do: {:ok, atom}, else: {:error, "module #{name} not loaded"}
  end

  defp resolve_module(name) when is_binary(name) do
    resolve_module("Elixir." <> name)
  end

  # ── Rendering ─────────────────────────────────────────────────

  defp render(module, module_doc, function_docs, params) do
    case params["function"] do
      nil ->
        render_module(module, module_doc, function_docs)

      function_name when is_binary(function_name) ->
        render_function(module, function_docs, function_name, params["arity"])
    end
  end

  defp render_module(module, module_doc, function_docs) do
    %{
      module: inspect(module),
      moduledoc: doc_text(module_doc),
      functions:
        function_docs
        |> Enum.flat_map(&summarise_function/1)
        |> Enum.sort_by(fn %{name: n, arity: a} -> {n, a} end)
    }
  end

  defp summarise_function({{kind, name, arity}, _anno, signature, doc, _meta})
       when kind in [:function, :macro] and doc != :hidden do
    [
      %{
        name: Atom.to_string(name),
        arity: arity,
        kind: Atom.to_string(kind),
        signature: Enum.join(signature, " "),
        summary: doc_first_line(doc)
      }
    ]
  end

  defp summarise_function(_), do: []

  defp render_function(module, function_docs, function_name, arity) do
    name_atom = String.to_atom(function_name)

    matches =
      function_docs
      |> Enum.filter(fn
        {{_kind, ^name_atom, a}, _, _, _, _} -> is_nil(arity) or a == arity
        _ -> false
      end)

    case matches do
      [] ->
        %{
          error: "no function #{inspect(module)}.#{function_name}#{arity_label(arity)} found",
          module: inspect(module)
        }

      [match] ->
        render_one_function(module, match)

      many ->
        %{
          module: inspect(module),
          arities: Enum.map(many, fn {{_, _, a}, _, _, _, _} -> a end),
          note: "multiple arities found; pass :arity to disambiguate"
        }
    end
  end

  defp render_one_function(module, {{kind, name, arity}, _anno, signature, doc, meta}) do
    %{
      module: inspect(module),
      function: Atom.to_string(name),
      arity: arity,
      kind: Atom.to_string(kind),
      signature: Enum.join(signature, " "),
      doc: doc_text(doc),
      spec: format_specs(meta[:specs]),
      since: meta[:since],
      deprecated: meta[:deprecated]
    }
    |> Enum.reject(fn {_, v} -> is_nil(v) end)
    |> Map.new()
  end

  # ── Helpers ───────────────────────────────────────────────────

  defp doc_text(%{"en" => doc}) when is_binary(doc), do: doc
  defp doc_text(:hidden), do: nil
  defp doc_text(:none), do: nil
  defp doc_text(_), do: nil

  defp doc_first_line(doc) do
    case doc_text(doc) do
      nil -> ""
      text -> text |> String.split("\n", parts: 2) |> List.first() |> String.trim()
    end
  end

  defp format_specs(nil), do: nil

  defp format_specs(specs) when is_list(specs) do
    Enum.map(specs, fn
      {{name, _arity}, spec_def} when is_atom(name) ->
        format_one_spec(name, spec_def)

      spec ->
        # Older `:specs` metadata shapes — pass through verbatim.
        inspect(spec)
    end)
  end

  defp format_one_spec(name, spec_def) do
    Code.Typespec.spec_to_quoted(name, spec_def) |> Macro.to_string()
  rescue
    _ -> inspect(spec_def)
  end

  defp arity_label(nil), do: ""
  defp arity_label(n), do: "/#{n}"
end

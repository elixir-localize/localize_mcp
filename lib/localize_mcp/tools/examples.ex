defmodule LocalizeMcp.Tools.Examples do
  @moduledoc """
  Implementation of the `localize_examples` tool.

  Reads curated example snippets from `priv/mcp/examples/<capability>.exs`.
  Each file evaluates to a list of `%{title, code, expected_output}`
  maps. The `code` field is a literal Elixir source snippet — agents
  can copy it verbatim — and `expected_output` documents what
  `iex>` returns for that snippet.

  The example files are reviewed under PR; runtime evaluation of
  the snippet doesn't happen here. The doctest-style runner in
  `test/` checks that each snippet still produces the documented
  output.

  """

  @capabilities ~w(
    format_number
    format_date
    format_time
    format_datetime
    format_currency
    format_unit
    format_duration
    format_interval
    format_message
    format_list
    collate
    parse_locale
    parse_currency
    parse_number
    translate
    translate_setup
    translate_headless
    translate_phoenix
    translate_liveview
  )

  @spec call(map()) :: map()
  def call(%{"capability" => capability}) when is_binary(capability) do
    if capability in @capabilities do
      case load_examples(capability) do
        {:ok, examples} ->
          %{capability: capability, examples: examples, total: length(examples)}

        {:error, :not_found} ->
          %{
            capability: capability,
            examples: [],
            note:
              "No example file found at priv/mcp/examples/#{capability}.exs. " <>
                "Contributions welcome — file lives in the localize_mcp repo."
          }

        {:error, reason} ->
          %{capability: capability, error: inspect(reason)}
      end
    else
      %{
        error: "unknown capability #{inspect(capability)}",
        known_capabilities: @capabilities
      }
    end
  end

  def call(_), do: %{error: "missing required parameter :capability"}

  @doc false
  @spec known_capabilities() :: [String.t()]
  def known_capabilities, do: @capabilities

  defp load_examples(capability) do
    path = examples_path(capability)

    if File.exists?(path) do
      try do
        {examples, _bindings} = Code.eval_file(path)
        {:ok, Enum.map(examples, &normalise_example/1)}
      rescue
        exception -> {:error, exception}
      end
    else
      {:error, :not_found}
    end
  end

  defp examples_path(capability) do
    Application.app_dir(:localize_mcp, ["priv", "mcp", "examples", "#{capability}.exs"])
  end

  # Each example carries at minimum a `:title`. Code, expected
  # output, prose, and target filename are all optional — setup-style
  # snippets often have `:filename` + `:code` + `:prose` and no
  # runnable output, while one-liner examples have `:code` + `:expected_output`
  # and no prose. Anything not provided is dropped from the response.
  defp normalise_example(%{title: title} = entry) do
    %{
      title: title,
      prose: Map.get(entry, :prose),
      filename: Map.get(entry, :filename),
      code: Map.get(entry, :code),
      expected_output: Map.get(entry, :expected_output)
    }
    |> Enum.reject(fn {_k, v} -> is_nil(v) end)
    |> Map.new()
  end

  defp normalise_example(other) do
    %{error: "malformed example: #{inspect(other)}"}
  end
end

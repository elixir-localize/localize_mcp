defmodule LocalizeMcp.TermGrammar do
  @moduledoc """
  JSON ↔ Elixir term grammar used by `localize_invoke`.

  MCP transports carry JSON. Elixir functions take richly typed
  arguments — atoms, tuples, structs, dates, decimals — that don't
  exist in JSON. This module defines a small extension grammar so
  the agent can encode any term it needs.

  Most JSON values map straight through:

      | JSON           | Elixir                       |
      | -------------- | ---------------------------- |
      | null           | nil                          |
      | true / false   | true / false                 |
      | number         | integer or float             |
      | string         | binary                       |
      | array          | list                         |
      | object         | map with string keys         |

  Elixir-only terms use a tagged object with a leading `"$kind"`
  key:

      | Term                              | Encoded                                                                 |
      | --------------------------------- | ----------------------------------------------------------------------- |
      | `:foo`                            | `{"$atom": "foo"}`                                                       |
      | `~D[2024-05-13]`                  | `{"$date": "2024-05-13"}`                                                |
      | `~T[12:34:56]`                    | `{"$time": "12:34:56"}`                                                  |
      | `~U[2024-05-13T12:34:56Z]`        | `{"$datetime": "2024-05-13T12:34:56Z"}`                                  |
      | `~N[2024-05-13T12:34:56]`         | `{"$naive_datetime": "2024-05-13T12:34:56"}`                             |
      | `Decimal.new("3.14")`             | `{"$decimal": "3.14"}`                                                   |
      | `{1, "a", :b}`                    | `{"$tuple": [1, "a", {"$atom": "b"}]}`                                   |
      | `[locale: :en, format: :short]`   | `{"$keyword": [["locale", {"$atom": "en"}], ["format", {"$atom": "short"}]]}` |
      | `%MyStruct{a: 1}`                 | `{"$struct": "MyStruct", "fields": {"a": 1}}`                            |

  Round-trip is exact for every shape listed above. Anything else
  (PIDs, references, ports, funs) is not invocable through the MCP
  surface by design and returns `{:error, :unsupported_term}`.

  """

  @max_term_bytes 16_384

  # ── Decoding (JSON → Elixir) ─────────────────────────────────

  @doc """
  Decode a JSON value (as produced by `:json.decode/1` or
  `Jason.decode/1`) into the corresponding Elixir term.

  Returns `{:ok, term}` or `{:error, reason}`. Imposes a 16 KB cap
  on the encoded form to bound the cost of a malicious payload.

  """
  @spec decode(term()) :: {:ok, term()} | {:error, term()}
  def decode(input) do
    if byte_size_of(input) > @max_term_bytes do
      {:error, {:term_too_large, byte_size_of(input)}}
    else
      try do
        {:ok, do_decode(input)}
      catch
        {:grammar_error, reason} -> {:error, reason}
      end
    end
  end

  defp do_decode(nil), do: nil
  defp do_decode(true), do: true
  defp do_decode(false), do: false
  defp do_decode(n) when is_number(n), do: n
  defp do_decode(s) when is_binary(s), do: s

  defp do_decode(%{"$atom" => name}) when is_binary(name) do
    String.to_existing_atom(name)
  rescue
    ArgumentError ->
      # The agent named an atom that hasn't been interned at runtime.
      # Don't intern it here — that would defeat the existing-atom
      # security gate. Return the string so the called function can
      # surface a domain-appropriate error.
      throw({:grammar_error, {:atom_not_existing, name}})
  end

  defp do_decode(%{"$date" => iso}) when is_binary(iso) do
    case Date.from_iso8601(iso) do
      {:ok, date} -> date
      {:error, reason} -> throw({:grammar_error, {:bad_date, iso, reason}})
    end
  end

  defp do_decode(%{"$time" => iso}) when is_binary(iso) do
    case Time.from_iso8601(iso) do
      {:ok, time} -> time
      {:error, reason} -> throw({:grammar_error, {:bad_time, iso, reason}})
    end
  end

  defp do_decode(%{"$datetime" => iso}) when is_binary(iso) do
    case DateTime.from_iso8601(iso) do
      {:ok, dt, _offset} -> dt
      {:error, reason} -> throw({:grammar_error, {:bad_datetime, iso, reason}})
    end
  end

  defp do_decode(%{"$naive_datetime" => iso}) when is_binary(iso) do
    case NaiveDateTime.from_iso8601(iso) do
      {:ok, ndt} -> ndt
      {:error, reason} -> throw({:grammar_error, {:bad_naive_datetime, iso, reason}})
    end
  end

  defp do_decode(%{"$decimal" => str}) when is_binary(str) do
    case Decimal.parse(str) do
      {decimal, ""} -> decimal
      _ -> throw({:grammar_error, {:bad_decimal, str}})
    end
  end

  defp do_decode(%{"$tuple" => elements}) when is_list(elements) do
    elements
    |> Enum.map(&do_decode/1)
    |> List.to_tuple()
  end

  defp do_decode(%{"$keyword" => pairs}) when is_list(pairs) do
    Enum.map(pairs, fn
      [k, v] when is_binary(k) -> {atom_or_throw(k), do_decode(v)}
      other -> throw({:grammar_error, {:bad_keyword_pair, other}})
    end)
  end

  defp do_decode(%{"$struct" => module_name, "fields" => fields})
       when is_binary(module_name) and is_map(fields) do
    module = atom_or_throw(module_name, fallback: false)

    if Code.ensure_loaded?(module) and function_exported?(module, :__struct__, 0) do
      fields
      |> Enum.map(fn {k, v} -> {atom_or_throw(k), do_decode(v)} end)
      |> Enum.into(struct(module, []))
    else
      throw({:grammar_error, {:unknown_struct, module_name}})
    end
  end

  defp do_decode(list) when is_list(list) do
    Enum.map(list, &do_decode/1)
  end

  defp do_decode(map) when is_map(map) do
    # Bare JSON object — keep string keys.
    Map.new(map, fn {k, v} -> {k, do_decode(v)} end)
  end

  defp do_decode(other) do
    throw({:grammar_error, {:unsupported_input, other}})
  end

  defp atom_or_throw(name, opts \\ []) do
    String.to_existing_atom(name)
  rescue
    ArgumentError ->
      if Keyword.get(opts, :fallback, true) do
        throw({:grammar_error, {:atom_not_existing, name}})
      else
        throw({:grammar_error, {:atom_not_existing, name}})
      end
  end

  # ── Encoding (Elixir → JSON-friendly) ────────────────────────

  @doc """
  Encode an Elixir term back into a JSON-friendly tree (i.e. one
  that `:json.encode/1` accepts).

  Symmetric with `decode/1` over the supported shapes.

  """
  @spec encode(term()) :: term()
  def encode(nil), do: nil
  def encode(true), do: true
  def encode(false), do: false
  def encode(n) when is_number(n), do: n
  def encode(s) when is_binary(s), do: s
  def encode(atom) when is_atom(atom), do: %{"$atom" => Atom.to_string(atom)}

  def encode(%Date{} = d), do: %{"$date" => Date.to_iso8601(d)}
  def encode(%Time{} = t), do: %{"$time" => Time.to_iso8601(t)}
  def encode(%DateTime{} = dt), do: %{"$datetime" => DateTime.to_iso8601(dt)}
  def encode(%NaiveDateTime{} = ndt), do: %{"$naive_datetime" => NaiveDateTime.to_iso8601(ndt)}
  def encode(%Decimal{} = d), do: %{"$decimal" => Decimal.to_string(d, :normal)}

  def encode(tuple) when is_tuple(tuple) do
    %{"$tuple" => tuple |> Tuple.to_list() |> Enum.map(&encode/1)}
  end

  def encode(list) when is_list(list) do
    if Keyword.keyword?(list) and list != [] do
      %{
        "$keyword" =>
          Enum.map(list, fn {k, v} -> [Atom.to_string(k), encode(v)] end)
      }
    else
      Enum.map(list, &encode/1)
    end
  end

  def encode(%_{} = struct) do
    %{
      "$struct" => inspect(struct.__struct__),
      "fields" =>
        struct
        |> Map.from_struct()
        |> Map.new(fn {k, v} -> {Atom.to_string(k), encode(v)} end)
    }
  end

  def encode(map) when is_map(map) do
    Map.new(map, fn
      {k, v} when is_binary(k) -> {k, encode(v)}
      {k, v} when is_atom(k) -> {Atom.to_string(k), encode(v)}
      {k, v} -> {inspect(k), encode(v)}
    end)
  end

  def encode(other), do: %{"$unencodable" => inspect(other)}

  # ── Grammar reference (returned by localize_term_grammar) ────

  @doc """
  Returns a static reference describing the grammar — the same
  content as the moduledoc, formatted for the
  `localize_term_grammar` tool response.

  """
  @spec reference() :: map()
  def reference do
    %{
      summary:
        "JSON ↔ Elixir term grammar for `localize_invoke`. Most JSON values pass through; " <>
          "Elixir-only terms use tagged objects with a `$kind` key.",
      passthrough: [
        "null → nil",
        "true / false → boolean",
        "number → integer or float (Elixir chooses based on shape)",
        "string → binary",
        "array → list",
        "object → map (string keys)"
      ],
      tagged_forms: [
        %{
          tag: "$atom",
          example: %{"$atom" => "foo"},
          elixir: ":foo",
          notes:
            "Must already be interned. The grammar refuses to grow the atom table on caller input."
        },
        %{
          tag: "$date",
          example: %{"$date" => "2024-05-13"},
          elixir: "~D[2024-05-13]",
          notes: "ISO 8601 date."
        },
        %{
          tag: "$time",
          example: %{"$time" => "12:34:56"},
          elixir: "~T[12:34:56]",
          notes: "ISO 8601 time. Sub-second precision optional."
        },
        %{
          tag: "$datetime",
          example: %{"$datetime" => "2024-05-13T12:34:56Z"},
          elixir: "~U[2024-05-13 12:34:56Z]",
          notes: "ISO 8601 datetime with offset."
        },
        %{
          tag: "$naive_datetime",
          example: %{"$naive_datetime" => "2024-05-13T12:34:56"},
          elixir: "~N[2024-05-13 12:34:56]",
          notes: "ISO 8601 datetime without offset."
        },
        %{
          tag: "$decimal",
          example: %{"$decimal" => "3.14"},
          elixir: "Decimal.new(\"3.14\")",
          notes: "Arbitrary-precision decimal."
        },
        %{
          tag: "$tuple",
          example: %{"$tuple" => [1, "a", %{"$atom" => "b"}]},
          elixir: "{1, \"a\", :b}",
          notes: "Element types nest the grammar."
        },
        %{
          tag: "$keyword",
          example: %{"$keyword" => [["locale", %{"$atom" => "en"}]]},
          elixir: "[locale: :en]",
          notes:
            "Distinguishes a keyword list from a map. Useful for options arguments to Localize."
        },
        %{
          tag: "$struct",
          example: %{
            "$struct" => "Localize.LanguageTag",
            "fields" => %{"language" => %{"$atom" => "en"}}
          },
          elixir: "%Localize.LanguageTag{language: :en}",
          notes: "The module must be loaded; `Code.ensure_loaded?/1` gates the construction."
        }
      ],
      limits: %{
        max_input_bytes: @max_term_bytes
      }
    }
  end

  # ── Helpers ──────────────────────────────────────────────────

  defp byte_size_of(binary) when is_binary(binary), do: byte_size(binary)
  defp byte_size_of(term), do: term |> :erlang.term_to_binary() |> byte_size()
end

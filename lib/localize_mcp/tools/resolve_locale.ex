defmodule LocalizeMcp.Tools.ResolveLocale do
  @moduledoc """
  Implementation of the `localize_resolve_locale` tool.

  Given a caller-supplied locale (atom or string), show every stage
  Localize takes to canonicalise it — parse → canonicalise → validate
  → resolve `cldr_locale_id` → walk the parent chain → membership in
  `:supported_locales`. Designed to answer the family of questions
  "is :en_au the right form?" / "does my locale fall back to en or
  und?" / "is this in my :supported_locales list?" in a single tool
  call.

  """

  @spec call(map()) :: map()
  def call(%{"input" => input}) do
    requested = normalise_input(input)

    %{
      requested: input,
      parsed: parse(requested),
      canonical: validate(requested),
      cldr_locale_id: cldr_locale_id(requested),
      parent_chain: parent_chain(requested),
      supported?: supported?(requested),
      runtime_interned?: atom_interned?(requested)
    }
  end

  def call(_), do: %{error: "missing required parameter :input"}

  # ── Input normalisation ──────────────────────────────────────

  defp normalise_input(input) when is_atom(input), do: input
  defp normalise_input(input) when is_binary(input), do: input
  defp normalise_input(other), do: inspect(other)

  # ── Stages ────────────────────────────────────────────────────

  defp parse(input) do
    case Localize.LanguageTag.parse(input) do
      {:ok, tag} ->
        %{
          ok: true,
          language: maybe_inspect(tag.language),
          script: maybe_inspect(tag.script),
          territory: maybe_inspect(tag.territory),
          variants: Enum.map(tag.language_variants || [], &inspect/1),
          requested_locale_id: maybe_inspect(tag.requested_locale_id)
        }

      {:error, exception} ->
        %{ok: false, error: Exception.message(exception)}
    end
  rescue
    exception -> %{ok: false, error: Exception.message(exception)}
  end

  defp validate(input) do
    case Localize.validate_locale(input) do
      {:ok, %Localize.LanguageTag{} = tag} ->
        %{
          ok: true,
          cldr_locale_id: maybe_inspect(tag.cldr_locale_id),
          canonical_locale_id: maybe_inspect(tag.canonical_locale_id),
          requested_locale_id: maybe_inspect(tag.requested_locale_id)
        }

      {:error, exception} ->
        %{ok: false, error: Exception.message(exception)}
    end
  rescue
    exception -> %{ok: false, error: Exception.message(exception)}
  end

  defp cldr_locale_id(input) do
    case Localize.Locale.cldr_locale_id_from(input) do
      {:ok, id} -> %{ok: true, id: inspect(id)}
      {:error, exception} -> %{ok: false, error: Exception.message(exception)}
    end
  rescue
    exception -> %{ok: false, error: Exception.message(exception)}
  end

  defp parent_chain(input) do
    case Localize.LanguageTag.parse(input) do
      {:ok, tag} -> walk_parents(tag, [tag_label(tag)], 16)
      _ -> []
    end
  rescue
    _ -> []
  end

  defp walk_parents(_tag, acc, 0), do: Enum.reverse(acc)

  defp walk_parents(tag, acc, fuel) do
    case Localize.Locale.parent(tag) do
      {:ok, parent} ->
        label = tag_label(parent)

        if label in acc do
          # Cycle guard
          Enum.reverse(acc)
        else
          walk_parents(parent, [label | acc], fuel - 1)
        end

      _ ->
        Enum.reverse(acc)
    end
  end

  defp tag_label(%Localize.LanguageTag{} = tag) do
    case Localize.LanguageTag.to_string(tag) do
      s when is_binary(s) -> s
      _ -> inspect(tag)
    end
  rescue
    _ -> inspect(tag)
  end

  defp supported?(input) do
    case Localize.Locale.cldr_locale_id_from(input) do
      {:ok, id} -> id in Localize.supported_locales()
      _ -> false
    end
  rescue
    _ -> false
  end

  defp atom_interned?(input) when is_binary(input) do
    _ = :erlang.binary_to_existing_atom(input, :utf8)
    true
  rescue
    ArgumentError -> false
  end

  defp atom_interned?(_), do: true

  defp maybe_inspect(nil), do: nil
  defp maybe_inspect(value), do: inspect(value)
end

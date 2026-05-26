defmodule LocalizeMcp.Tools.Validate do
  @moduledoc """
  Implementation of the `localize_validate` tool.

  Kind-aware validator. Given a `kind` (currency, calendar,
  territory, script, number_system, language, locale) and a binary
  or atom `value`, returns a structured record showing whether
  Localize accepts the input and what canonical atom (if any) it
  resolves to.

  Backed by the existing `Localize.X.validate_*` accessors. Thin
  facade — the value is the consistent output shape across kinds.

  """

  @kinds ~w(currency calendar territory script number_system language locale)

  @spec call(map()) :: map()
  def call(%{"kind" => kind, "value" => value}) when is_binary(kind) do
    if kind in @kinds do
      run(kind, value)
    else
      %{error: "unknown kind #{inspect(kind)}", known_kinds: @kinds}
    end
  end

  def call(_), do: %{error: "required parameters: :kind, :value"}

  # ── Dispatch ────────────────────────────────────────────────

  defp run("currency", value), do: wrap("currency", value, &Localize.Currency.validate_currency/1)
  defp run("calendar", value), do: wrap("calendar", value, &Localize.validate_calendar/1)
  defp run("territory", value), do: wrap("territory", value, &Localize.validate_territory/1)
  defp run("script", value), do: wrap("script", value, &Localize.validate_script/1)
  defp run("number_system", value), do: wrap("number_system", value, &Localize.validate_number_system/1)
  defp run("language", value), do: validate_language(value)
  defp run("locale", value), do: validate_locale(value)

  defp wrap(kind, value, fun) do
    case fun.(value) do
      {:ok, canonical} ->
        %{kind: kind, input: value, valid?: true, canonical: inspect(canonical)}

      {:error, exception} ->
        %{
          kind: kind,
          input: value,
          valid?: false,
          error: %{module: inspect(exception.__struct__), message: Exception.message(exception)}
        }
    end
  rescue
    exception ->
      %{
        kind: kind,
        input: value,
        valid?: false,
        error: %{module: inspect(exception.__struct__), message: Exception.message(exception)}
      }
  end

  defp validate_locale(value) do
    case Localize.validate_locale(value) do
      {:ok, %Localize.LanguageTag{cldr_locale_id: id}} ->
        %{kind: "locale", input: value, valid?: true, canonical: inspect(id)}

      {:error, exception} ->
        %{
          kind: "locale",
          input: value,
          valid?: false,
          error: %{module: inspect(exception.__struct__), message: Exception.message(exception)}
        }
    end
  rescue
    exception ->
      %{
        kind: "locale",
        input: value,
        valid?: false,
        error: %{module: inspect(exception.__struct__), message: Exception.message(exception)}
      }
  end

  # `Localize.Validity.Language.validate/1` returns
  # `{:ok, code, status}` on success (where status is e.g.
  # `:regular`, `:deprecated`) and `{:error, code}` on miss. Flatten
  # to the common `valid?: bool, canonical: string` shape.
  defp validate_language(value) do
    case Localize.Validity.Language.validate(value) do
      {:ok, code, _status} ->
        %{kind: "language", input: value, valid?: true, canonical: inspect(code)}

      {:error, _} ->
        %{
          kind: "language",
          input: value,
          valid?: false,
          error: %{
            module: "Localize.UnknownLanguageError",
            message: "Unknown language code: #{inspect(value)}"
          }
        }
    end
  rescue
    exception ->
      %{
        kind: "language",
        input: value,
        valid?: false,
        error: %{module: inspect(exception.__struct__), message: Exception.message(exception)}
      }
  end

  @doc false
  def known_kinds, do: @kinds
end

defmodule LocalizeMcp.Tools.ResolutionTest do
  use ExUnit.Case, async: true

  alias LocalizeMcp.Tools.{ResolveLocale, Validate}

  describe "ResolveLocale" do
    test "returns every stage for a known locale" do
      result = ResolveLocale.call(%{"input" => "en-AU"})

      assert result.requested == "en-AU"
      assert result.parsed.ok == true
      assert result.canonical.ok == true
      assert result.cldr_locale_id.ok == true
      assert is_boolean(result.supported?)
      assert is_boolean(result.runtime_interned?)
    end

    test "POSIX-style input falls cleanly" do
      result = ResolveLocale.call(%{"input" => "pt_BR"})
      assert result.parsed.ok == true
    end

    test "missing :input returns error" do
      assert %{error: _} = ResolveLocale.call(%{})
    end
  end

  describe "Validate" do
    test "currency USD" do
      assert %{kind: "currency", input: "USD", valid?: true, canonical: ":USD"} =
               Validate.call(%{"kind" => "currency", "value" => "USD"})
    end

    test "currency XYZ unknown" do
      assert %{valid?: false, error: %{message: _}} =
               Validate.call(%{"kind" => "currency", "value" => "XYZ"})
    end

    test "calendar gregorian" do
      assert %{valid?: true, canonical: ":gregorian"} =
               Validate.call(%{"kind" => "calendar", "value" => "gregorian"})
    end

    test "territory US" do
      assert %{valid?: true, canonical: ":US"} =
               Validate.call(%{"kind" => "territory", "value" => "US"})
    end

    test "script Latn" do
      assert %{valid?: true, canonical: ":Latn"} =
               Validate.call(%{"kind" => "script", "value" => "Latn"})
    end

    test "number_system arab" do
      assert %{valid?: true, canonical: ":arab"} =
               Validate.call(%{"kind" => "number_system", "value" => "arab"})
    end

    test "language en" do
      assert %{valid?: true} =
               Validate.call(%{"kind" => "language", "value" => "en"})
    end

    test "locale en-US" do
      assert %{valid?: true} =
               Validate.call(%{"kind" => "locale", "value" => "en-US"})
    end

    test "unknown kind returns error" do
      assert %{error: _, known_kinds: kinds} =
               Validate.call(%{"kind" => "widget", "value" => "x"})

      assert is_list(kinds)
    end
  end
end

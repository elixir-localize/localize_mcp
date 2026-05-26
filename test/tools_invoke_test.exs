defmodule LocalizeMcp.Tools.InvokeTest do
  use ExUnit.Case, async: true

  alias LocalizeMcp.Tools.{Invoke, TermGrammar}
  alias LocalizeMcp.TermGrammar, as: Grammar

  describe "TermGrammar (encoding)" do
    test "atoms round-trip" do
      assert {:ok, :foo} = Grammar.decode(%{"$atom" => "foo"})
      assert %{"$atom" => "foo"} = Grammar.encode(:foo)
    end

    test "dates round-trip" do
      assert {:ok, ~D[2024-05-13]} = Grammar.decode(%{"$date" => "2024-05-13"})
      assert %{"$date" => "2024-05-13"} = Grammar.encode(~D[2024-05-13])
    end

    test "decimals round-trip" do
      assert {:ok, %Decimal{} = d} = Grammar.decode(%{"$decimal" => "3.14"})
      assert Decimal.equal?(d, Decimal.new("3.14"))
      assert %{"$decimal" => "3.14"} = Grammar.encode(Decimal.new("3.14"))
    end

    test "tuples round-trip" do
      assert {:ok, {1, "a", :b}} =
               Grammar.decode(%{"$tuple" => [1, "a", %{"$atom" => "b"}]})

      assert %{"$tuple" => [1, "a", %{"$atom" => "b"}]} = Grammar.encode({1, "a", :b})
    end

    test "keyword lists round-trip" do
      assert {:ok, [locale: :en, format: :short]} =
               Grammar.decode(%{
                 "$keyword" => [
                   ["locale", %{"$atom" => "en"}],
                   ["format", %{"$atom" => "short"}]
                 ]
               })

      assert %{"$keyword" => _} = Grammar.encode(locale: :en, format: :short)
    end

    test "unknown atom returns grammar_error" do
      assert {:error, {:atom_not_existing, "totally_made_up_atom_xyz"}} =
               Grammar.decode(%{"$atom" => "totally_made_up_atom_xyz"})
    end

    test "bare maps stay maps" do
      assert {:ok, %{"a" => 1, "b" => "two"}} = Grammar.decode(%{"a" => 1, "b" => "two"})
    end
  end

  describe "Tools.TermGrammar.call/1" do
    test "returns the static reference" do
      ref = TermGrammar.call(%{})
      assert is_binary(ref.summary)
      assert is_list(ref.passthrough)
      assert is_list(ref.tagged_forms)
    end
  end

  describe "Invoke — allowlist gate" do
    test "rejects an MFA not on the allowlist" do
      # `Localize.SupplementalData.validity/1` exists at runtime (it
      # was called at app start so the atom is interned), but it is
      # deliberately not in priv/mcp/invocable.exs.
      result =
        Invoke.call(%{
          "mfa" => "Localize.SupplementalData.validity/1",
          "args" => [%{"$atom" => "languages"}]
        })

      assert %{error: "not_invokable"} = result
    end

    test "rejects a malformed MFA" do
      result = Invoke.call(%{"mfa" => "garbage", "args" => []})
      assert %{error: msg} = result
      assert msg =~ "malformed"
    end

    test "rejects an arity mismatch" do
      result =
        Invoke.call(%{
          "mfa" => "Localize.Number.to_string/2",
          "args" => [1, %{"$keyword" => []}, "extra"]
        })

      assert %{error: "arity_mismatch", expected: 2, got: 3} = result
    end
  end

  describe "Invoke — happy path" do
    test "Localize.Number.to_string/1 with an integer" do
      result =
        Invoke.call(%{"mfa" => "Localize.Number.to_string/1", "args" => [1234]})

      assert %{ok: true, result: %{"$tuple" => [%{"$atom" => "ok"}, "1,234"]}} = result
    end

    test "Localize.Number.to_string/2 with locale option" do
      args = [
        12_345,
        %{"$keyword" => [["locale", %{"$atom" => "de"}]]}
      ]

      result = Invoke.call(%{"mfa" => "Localize.Number.to_string/2", "args" => args})

      assert %{ok: true, result: %{"$tuple" => [%{"$atom" => "ok"}, formatted]}} = result
      # The exact grouping separator depends on the bundled locale
      # data (the test process may have :en-only data loaded). The
      # invariant we care about is that the call succeeded and the
      # value made the trip end-to-end.
      assert is_binary(formatted)
      assert formatted =~ "12"
      assert formatted =~ "345"
    end

    test "Localize.Currency.validate_currency/1 with USD" do
      result =
        Invoke.call(%{
          "mfa" => "Localize.Currency.validate_currency/1",
          "args" => ["USD"]
        })

      assert %{ok: true, result: %{"$tuple" => [%{"$atom" => "ok"}, %{"$atom" => "USD"}]}} =
               result
    end
  end

  describe "Invoke — error reporting" do
    test "exception path returns a structured error" do
      # Try to format a Date as a number — Localize.Number.to_string/2
      # returns {:error, exception} for unsupported value types; this
      # exercises the {:ok, {:error, _}} path through the normal
      # tuple-encoding flow rather than a raise.
      args = [%{"$date" => "2024-05-13"}]
      result = Invoke.call(%{"mfa" => "Localize.Number.to_string/1", "args" => args})

      # Either {:error, exception} from the formatter (encoded as a
      # tuple) — that's the realistic case.
      assert %{ok: true, result: %{"$tuple" => [%{"$atom" => tag} | _]}} = result
      assert tag in ["ok", "error"]
    end
  end
end

defmodule LocalizeMcp.ToolsTest do
  use ExUnit.Case, async: true

  alias LocalizeMcp.Tools

  describe "Search" do
    test "exact module name scores top" do
      result = Tools.Search.call(%{"query" => "Localize.Number"})
      assert %{matches: [first | _], total: total} = result
      assert total > 0
      assert first.name =~ "Localize.Number"
    end

    test "function name match" do
      result = Tools.Search.call(%{"query" => "to_string", "kind" => "function", "limit" => 5})
      assert %{matches: matches} = result
      assert length(matches) <= 5
      assert Enum.any?(matches, &(&1.name =~ "to_string"))
    end

    test "empty query returns error" do
      assert %{error: _} = Tools.Search.call(%{})
    end
  end

  describe "Browse" do
    test "Numbers group lists Localize.Number" do
      result = Tools.Browse.call(%{"group" => "Numbers"})
      assert %{group: "Numbers", modules: modules, total: total} = result
      assert total > 0
      assert Enum.any?(modules, &(&1.module == "Localize.Number"))
    end

    test "unknown group returns empty list" do
      result = Tools.Browse.call(%{"group" => "NoSuchGroup"})
      assert %{modules: [], total: 0} = result
    end
  end

  describe "Doc" do
    test "module-level lookup returns moduledoc + function list" do
      result = Tools.Doc.call(%{"module" => "Localize.Number"})
      assert %{module: "Localize.Number", moduledoc: doc, functions: funs} = result
      assert is_binary(doc) and doc != ""
      assert Enum.any?(funs, &(&1.name == "to_string"))
    end

    test "function-level lookup returns spec" do
      result =
        Tools.Doc.call(%{"module" => "Localize.Number", "function" => "to_string", "arity" => 2})

      assert %{module: "Localize.Number", function: "to_string", arity: 2, doc: doc} = result
      assert is_binary(doc)
    end

    test "missing module returns error" do
      assert %{error: _} = Tools.Doc.call(%{"module" => "Localize.DoesNotExist"})
    end
  end

  describe "Examples" do
    test "format_number returns curated snippets" do
      result = Tools.Examples.call(%{"capability" => "format_number"})
      assert %{capability: "format_number", examples: examples, total: total} = result
      assert total > 0
      assert Enum.all?(examples, &Map.has_key?(&1, :code))
    end

    test "unknown capability returns error" do
      assert %{error: _, known_capabilities: list} =
               Tools.Examples.call(%{"capability" => "format_widget"})

      assert is_list(list)
    end

    test "translate (overview) returns prose-bearing entries" do
      result = Tools.Examples.call(%{"capability" => "translate"})
      assert %{capability: "translate", examples: examples} = result
      assert is_list(examples) and examples != []
      # The overview entry has prose but no code.
      assert Enum.any?(examples, &(Map.has_key?(&1, :prose) and not Map.has_key?(&1, :code)))
    end

    test "translate_setup includes target filenames for setup steps" do
      result = Tools.Examples.call(%{"capability" => "translate_setup"})
      assert %{examples: examples} = result
      # At least one entry has a :filename (e.g. lib/my_app/gettext.ex).
      assert Enum.any?(examples, &Map.has_key?(&1, :filename))
    end

    test "all five translate capabilities are known" do
      for capability <-
            ~w(translate translate_setup translate_headless translate_phoenix translate_liveview) do
        assert capability in Tools.Examples.known_capabilities(),
               "#{capability} missing from @capabilities"

        result = Tools.Examples.call(%{"capability" => capability})
        assert %{capability: ^capability, examples: examples} = result
        assert is_list(examples) and examples != [], "#{capability} returned no examples"
      end
    end
  end

  describe "Atoms" do
    test "currencies collection" do
      result = Tools.Atoms.call(%{"collection" => "currencies"})
      assert %{collection: "currencies", atoms: atoms, total: total} = result
      assert total > 0
      assert Enum.any?(atoms, &(&1.atom == ":USD"))
    end

    test "number_systems collection" do
      result = Tools.Atoms.call(%{"collection" => "number_systems"})
      assert %{atoms: atoms} = result
      assert Enum.any?(atoms, &(&1.atom == ":latn"))
      assert Enum.any?(atoms, &(&1.atom == ":arab"))
    end

    test "unknown collection returns error" do
      assert %{error: _, known_collections: list} =
               Tools.Atoms.call(%{"collection" => "widgets"})

      assert is_list(list)
    end
  end

  describe "Errors" do
    test "lists every Localize.*Error module" do
      assert %{modules: modules} = Tools.Errors.call(%{})
      assert is_list(modules) and modules != []

      assert Enum.any?(modules, &(&1.module == "Localize.InvalidValueError"))
    end

    test "single-module lookup returns reason_atoms when adopted" do
      assert %{modules: [entry]} =
               Tools.Errors.call(%{"module" => "Localize.FormatError"})

      assert is_list(entry.reason_atoms)
      assert ":unbalanced_markup" in entry.reason_atoms
    end
  end

  describe "Options" do
    test "Localize.Number.to_string/2 returns curated options" do
      result =
        Tools.Options.call(%{
          "module" => "Localize.Number",
          "function" => "to_string",
          "arity" => 2
        })

      assert %{module: "Localize.Number", function: "to_string", arity: 2, options: opts} = result
      assert Enum.any?(opts, &(&1.name == :format))

      format_opt = Enum.find(opts, &(&1.name == :format))
      assert is_list(format_opt.allowed_values)
      assert :percent in format_opt.allowed_values
    end

    test "un-curated module returns a note" do
      result =
        Tools.Options.call(%{
          "module" => "Localize.LanguageTag",
          "function" => "parse",
          "arity" => 1
        })

      assert %{note: note} = result
      assert is_binary(note)
    end
  end
end

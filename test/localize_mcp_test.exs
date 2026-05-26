defmodule LocalizeMcpTest do
  use ExUnit.Case, async: true

  describe "boot probes" do
    test "version/0 returns a non-empty string" do
      assert is_binary(LocalizeMcp.version())
      assert LocalizeMcp.version() != ""
    end

    test "calendrical_loaded?/0 reflects Code.ensure_loaded?" do
      assert LocalizeMcp.calendrical_loaded?() == Code.ensure_loaded?(Calendrical)
    end

    test "localize_web_loaded?/0 reflects Code.ensure_loaded?" do
      assert LocalizeMcp.localize_web_loaded?() == Code.ensure_loaded?(LocalizeWeb)
    end
  end

  describe "Index" do
    test "entries/0 includes Localize core modules" do
      entries = LocalizeMcp.Index.build()
      module_names = entries |> Enum.map(& &1.module) |> Enum.uniq()

      assert Localize.Number in module_names
      assert Localize.Date in module_names
      assert Localize.Currency in module_names
    end

    test "entries are grouped" do
      entries = LocalizeMcp.Index.build()
      groups = entries |> Enum.map(& &1.group) |> Enum.uniq() |> MapSet.new()

      assert "Numbers" in groups
      assert "Dates and Times" in groups
      assert "Locale" in groups
    end
  end
end

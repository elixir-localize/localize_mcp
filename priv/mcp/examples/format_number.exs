# Curated example snippets for the `format_number` capability.
# Returned verbatim by the `localize_examples` MCP tool.
#
# Each entry is a map with:
#   :title             - one-line label
#   :code              - the Elixir snippet to copy
#   :expected_output   - what `iex>` returns for that snippet
#
# Keep this file under PR review; the doctest-style test runner in
# test/examples_runner_test.exs asserts each snippet still produces
# its documented output.

[
  %{
    title: "Default locale, default format",
    code: "Localize.Number.to_string(1_234_567.89)",
    expected_output: "{:ok, \"1,234,567.89\"}"
  },
  %{
    title: "Percent format",
    code: "Localize.Number.to_string(0.456, format: :percent)",
    expected_output: "{:ok, \"46%\"}"
  },
  %{
    title: "Specific locale (German)",
    code: "Localize.Number.to_string(1_234.5, locale: :de)",
    expected_output: "{:ok, \"1.234,5\"}"
  },
  %{
    title: "Currency format",
    code: "Localize.Number.to_string(1234, format: :currency, currency: :USD)",
    expected_output: "{:ok, \"$1,234.00\"}"
  },
  %{
    title: "Override the number system (Arabic-Indic digits)",
    code: "Localize.Number.to_string(12345, locale: \"ar\", number_system: :arab)",
    expected_output: "{:ok, \"١٢٬٣٤٥\"}"
  }
]

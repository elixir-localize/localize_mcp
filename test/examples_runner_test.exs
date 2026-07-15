defmodule LocalizeMcp.ExamplesRunnerTest do
  use ExUnit.Case, async: false

  # Doctest-style runner over the curated example library: every
  # entry that documents an `expected_output` is executed and the
  # `inspect` of its result compared, so a Localize upgrade cannot
  # silently invalidate the snippets the `localize_examples` tool
  # serves. Entries without `expected_output` (prose, setup and
  # framework snippets) are skipped.

  examples_dir = Path.expand("../priv/mcp/examples", __DIR__)

  for file <- Path.wildcard(Path.join(examples_dir, "*.exs")),
      basename = Path.basename(file),
      {example, index} <- file |> Code.eval_file() |> elem(0) |> Enum.with_index(),
      is_binary(example[:expected_output]) and is_binary(example[:code]) do
    @code example.code
    @expected example.expected_output

    test "#{basename} ##{index} — #{example.title}" do
      {result, _binding} = Code.eval_string(@code)
      assert inspect(result) == @expected
    end
  end
end

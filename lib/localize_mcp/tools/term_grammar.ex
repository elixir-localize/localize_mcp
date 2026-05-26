defmodule LocalizeMcp.Tools.TermGrammar do
  @moduledoc """
  Implementation of the `localize_term_grammar` tool.

  Returns the static JSON ↔ Elixir term grammar reference, the same
  shape as `LocalizeMcp.TermGrammar.reference/0`.

  """

  @spec call(map()) :: map()
  def call(_params), do: LocalizeMcp.TermGrammar.reference()
end

[
  %{
    title: "Default locale (en-US), default format (medium)",
    code: "Localize.Date.to_string(~D[2025-03-22])",
    expected_output: "{:ok, \"Mar 22, 2025\"}"
  },
  %{
    title: "Short format, German locale",
    code: "Localize.Date.to_string(~D[2025-03-22], locale: :de, format: :short)",
    expected_output: "{:ok, \"22.03.25\"}"
  },
  %{
    title: "Long format, Japanese locale (gregorian)",
    code: "Localize.Date.to_string(~D[2025-03-22], locale: :\"ja-JP\", format: :long)",
    expected_output: "{:ok, \"2025年3月22日\"}"
  },
  %{
    title: "Custom skeleton",
    code: "Localize.Date.to_string(~D[2025-03-22], format: :yMMMM)",
    expected_output: "{:ok, \"March 2025\"}"
  }
]

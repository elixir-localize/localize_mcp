# Curated option metadata for Localize.Number.
#
# This file maps {function_name, arity} to a list of option specs.
# Each spec describes one keyword option — its expected type, the
# closed set of allowed values where applicable, the default, and a
# one-line description.
#
# Returned by the `localize_options` MCP tool. Maintained by hand;
# add new entries as the API evolves.

%{
  {:to_string, 2} => [
    %{
      name: :locale,
      type: "atom() | String.t() | Localize.LanguageTag.t()",
      allowed_values: nil,
      default: "Localize.get_locale/0",
      description: "The locale to format under. Default: current process locale."
    },
    %{
      name: :format,
      type: "atom()",
      allowed_values: [
        :standard,
        :decimal,
        :currency,
        :accounting,
        :percent,
        :permille,
        :scientific,
        :short,
        :long,
        :integer
      ],
      default: ":standard",
      description: "Named format style. :short and :long render compact forms (1K, 1 thousand)."
    },
    %{
      name: :currency,
      type: "atom() | String.t()",
      allowed_values: nil,
      default: "nil",
      description: "Required when :format is :currency or :accounting. ISO 4217 code."
    },
    %{
      name: :currency_symbol,
      type: "atom()",
      allowed_values: [:standard, :iso, :narrow, :none],
      default: ":standard",
      description: "Which currency symbol form to use. :iso renders the three-letter code."
    },
    %{
      name: :number_system,
      type: "atom() | String.t()",
      allowed_values: nil,
      default: "locale default (e.g. :latn for en, :arab for ar)",
      description: "Number system to render digits in. See localize_atoms collection=number_systems."
    },
    %{
      name: :rounding_mode,
      type: "atom()",
      allowed_values: [
        :half_up,
        :half_even,
        :half_down,
        :up,
        :down,
        :ceiling,
        :floor
      ],
      default: ":half_even",
      description: "Decimal rounding mode."
    },
    %{
      name: :minimum_integer_digits,
      type: "non_neg_integer()",
      allowed_values: nil,
      default: "format-dependent",
      description: "Minimum number of integer digits before the decimal point."
    },
    %{
      name: :minimum_fraction_digits,
      type: "non_neg_integer()",
      allowed_values: nil,
      default: "format-dependent",
      description: "Minimum fraction digits. Pads with trailing zeros."
    },
    %{
      name: :maximum_fraction_digits,
      type: "non_neg_integer()",
      allowed_values: nil,
      default: "format-dependent",
      description: "Maximum fraction digits. Triggers rounding."
    },
    %{
      name: :minimum_significant_digits,
      type: "1..21",
      allowed_values: nil,
      default: "nil",
      description: "ECMA-402 significant-digit minimum."
    },
    %{
      name: :maximum_significant_digits,
      type: "1..21",
      allowed_values: nil,
      default: "nil",
      description: "ECMA-402 significant-digit maximum."
    },
    %{
      name: :use_grouping,
      type: "atom() | boolean()",
      allowed_values: [:auto, :always, :never, :min2, true, false],
      default: ":auto",
      description: "Whether to insert grouping separators (thousands)."
    }
  ],
  {:parse, 2} => [
    %{
      name: :locale,
      type: "atom() | String.t() | Localize.LanguageTag.t()",
      allowed_values: nil,
      default: "Localize.get_locale/0",
      description: "The locale whose decimal/grouping symbols to parse."
    },
    %{
      name: :number,
      type: "atom()",
      allowed_values: [:decimal, :integer, :float],
      default: ":decimal",
      description: "Which numeric type to return."
    }
  ]
}

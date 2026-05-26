# Allowlist of invokable MFAs for `localize_invoke`.
#
# Every entry is `{module, function_atom, arity}`. The MCP server
# refuses any call to an MFA not present in this list, returning
# `not_invokable` with the allowlist for reference.
#
# Curation rules:
#
#   1. Read-only only. No `put_*`, no `store/_`, no Mix tasks, no
#      filesystem writers, no NIF entry points that can stall a
#      scheduler.
#
#   2. Public API only. Functions whose moduledoc is `@moduledoc
#      false` or whose `@doc` is `false` do not belong here.
#
#   3. Side-effect-free in the BEAM sense. The supplemental ETF
#      readers are fine because they only touch `:persistent_term`
#      and the global atom table (and the atom interning is now
#      eager via `Localize.Supervisor.intern_supplemental_atoms/0`).
#
# Add new entries with a one-line justification comment so the next
# reviewer doesn't have to reverse-engineer the choice.

[
  # ── Number formatting / parsing ───────────────────────────────
  {Localize.Number, :to_string, 1},
  {Localize.Number, :to_string, 2},
  {Localize.Number, :parse, 1},
  {Localize.Number, :parse, 2},

  # ── Date / Time / DateTime / Interval / Duration ──────────────
  {Localize.Date, :to_string, 1},
  {Localize.Date, :to_string, 2},
  {Localize.Time, :to_string, 1},
  {Localize.Time, :to_string, 2},
  {Localize.DateTime, :to_string, 1},
  {Localize.DateTime, :to_string, 2},
  {Localize.Interval, :to_string, 2},
  {Localize.Interval, :to_string, 3},
  {Localize.Duration, :to_string, 1},
  {Localize.Duration, :to_string, 2},

  # ── Unit ──────────────────────────────────────────────────────
  {Localize.Unit, :new, 1},
  {Localize.Unit, :new, 2},
  {Localize.Unit, :new, 3},
  {Localize.Unit, :to_string, 1},
  {Localize.Unit, :to_string, 2},
  {Localize.Unit, :parse, 1},
  {Localize.Unit, :convert, 2},
  {Localize.Unit, :decompose, 2},

  # ── List ──────────────────────────────────────────────────────
  {Localize.List, :to_string, 1},
  {Localize.List, :to_string, 2},

  # ── Message / MF2 ─────────────────────────────────────────────
  {Localize.Message, :format, 1},
  {Localize.Message, :format, 2},
  {Localize.Message, :format, 3},
  {Localize.Message, :format_to_iolist, 1},
  {Localize.Message, :format_to_iolist, 2},

  # ── Language tag / locale ─────────────────────────────────────
  {Localize.LanguageTag, :parse, 1},
  {Localize.LanguageTag, :canonicalize, 1},
  {Localize.Locale, :parent, 1},
  {Localize.Locale, :cldr_locale_id_from, 1},
  {Localize, :validate_locale, 1},

  # ── Validators ────────────────────────────────────────────────
  {Localize.Currency, :validate_currency, 1},
  {Localize, :validate_calendar, 1},
  {Localize, :validate_territory, 1},
  {Localize, :validate_script, 1},
  {Localize, :validate_number_system, 1},
  {Localize, :validate_territory_subdivision, 1},

  # ── Display names ─────────────────────────────────────────────
  {Localize.Language, :display_name, 1},
  {Localize.Language, :display_name, 2},
  {Localize.Script, :display_name, 1},
  {Localize.Script, :display_name, 2},
  {Localize.Territory, :display_name, 1},
  {Localize.Territory, :display_name, 2},
  {Localize.Currency, :display_name, 1},
  {Localize.Currency, :display_name, 2},

  # ── Misc accessors ────────────────────────────────────────────
  {Localize, :default_locale, 0},
  {Localize, :supported_locales, 0},
  {Localize.Number.System, :system_name_from, 2},
  {Localize.Number.System, :number_systems_for, 1}
]

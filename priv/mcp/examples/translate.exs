# Umbrella entry for the `translate` capability.
#
# A short orientation plus pointers to the more focused capabilities.
# Agents that just ran `localize_examples capability=translate` should
# follow up with one of `translate_setup`, `translate_headless`,
# `translate_phoenix`, or `translate_liveview` based on the kind of
# app they're working in.

[
  %{
    title: "Overview — how Localize handles translations",
    prose: """
    Localize uses **MessageFormat 2 (MF2)** as its message format and **Gettext** as the
    translation store. The recommended way to wire them together is the `~t` sigil from
    `Localize.Message.Sigils`:

    * **At compile time**, `~t"Hello, \#{name}!"` is rewritten into a Gettext lookup with
      MF2 placeholders. The msgid stored in your `.po` files is the canonical MF2 form
      (`"Hello, {$name}!"`) so translators can use MF2 features (plural selectors,
      formatters, markup) per-locale.
    * **At runtime**, the lookup runs against the configured Gettext backend, with
      `Localize.Gettext.Interpolation` handling the MF2 binding interpolation.

    The full surface is small:

    * `~t` — the compile-time translation sigil. Use everywhere you'd otherwise call
      `Gettext.gettext/2`.
    * `~M` — a compile-time *validation* sigil. Use for static MF2 messages that don't
      need translation (e.g. seed data, fixtures, format strings).
    * `Localize.Message.format/3` — the runtime API. Use when the msgid is dynamic
      (loaded from a database, computed at runtime).
    * `Localize.HTML.Message` — a Phoenix component that renders MF2 *with markup*
      (`{#bold}...{/bold}`, `{#link href=|/x|}...{/link}`) as HEEx. Use in Phoenix /
      LiveView templates when your translations contain inline links, emphasis, etc.

    Next steps:

    * **Setting up a new project?** Run `localize_examples capability=translate_setup`.
    * **Headless library or CLI?** Run `localize_examples capability=translate_headless`.
    * **Phoenix MVC?** Run `localize_examples capability=translate_phoenix`.
    * **LiveView?** Run `localize_examples capability=translate_liveview`.
    """
  },
  %{
    title: "The ~t sigil at a glance",
    code: ~S'''
    defmodule MyApp.Greeter do
      use Localize.Message.Sigils, backend: MyApp.Gettext

      def hello(name) do
        ~t"Hello, #{name}!"
      end
    end
    ''',
    expected_output:
      "Rewrites to a Gettext lookup of msgid \"Hello, {$name}!\" with bindings %{name: name}."
  },
  %{
    title: "Pluralisation with MF2 selectors",
    code: ~S'''
    defmodule MyApp.Notifications do
      use Localize.Message.Sigils, backend: MyApp.Gettext

      def unread_count(n) do
        ~t"""
        .input {$count :integer}
        .match $count
        0   {{No unread messages.}}
        1   {{One unread message.}}
        *   {{#{n = n} unread messages.}}
        """
      end
    end
    '''
  }
]

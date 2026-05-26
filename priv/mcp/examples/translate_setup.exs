# Setup snippets for getting translation working in any Localize-based
# app. The same Gettext backend wiring works for headless, Phoenix, and
# LiveView projects; the framework-specific glue is covered by the
# `translate_phoenix` and `translate_liveview` capabilities.

[
  %{
    title: "Step 1 — add deps to mix.exs",
    filename: "mix.exs",
    code: ~S'''
    defp deps do
      [
        # Localize itself.
        {:localize, "~> 0.38"},

        # Gettext is the translation store. Required.
        {:gettext, "~> 1.0"}
      ]
    end
    ''',
    prose: """
    Run `mix deps.get` after editing.
    """
  },
  %{
    title: "Step 2 — define a Gettext backend with MF2 interpolation",
    filename: "lib/my_app/gettext.ex",
    code: ~S'''
    defmodule MyApp.Gettext do
      use Gettext.Backend,
        otp_app: :my_app,
        interpolation: Localize.Gettext.Interpolation
    end
    ''',
    prose: """
    The `interpolation: Localize.Gettext.Interpolation` line is the critical bit. Without it,
    Gettext's default interpolation only understands `%{name}` placeholders — the MF2
    `{$name}` placeholders that `~t` generates would be returned literally.
    """
  },
  %{
    title: "Step 3 — create the PO directory layout",
    code: ~S'''
    mix gettext.extract           # walks lib/ for ~t and ~M usages, emits priv/gettext/default.pot
    mix gettext.merge priv/gettext --locale=de
    mix gettext.merge priv/gettext --locale=fr
    ''',
    prose: """
    Gettext expects `priv/gettext/<locale>/LC_MESSAGES/<domain>.po`. The first `extract`
    seeds `default.pot`; subsequent `merge` calls per-locale create the editable PO files
    translators work in. Re-run `extract` + `merge` whenever you add or change a `~t`.
    """
  },
  %{
    title: "Step 4 — opt the calling module in to ~t",
    code: ~S'''
    defmodule MyApp.Greeter do
      use Localize.Message.Sigils, backend: MyApp.Gettext

      def hello(name), do: ~t"Hello, #{name}!"
    end
    ''',
    prose: """
    Every module that uses `~t` needs the `use Localize.Message.Sigils, backend: …` line.
    The `:backend` keyword names your Gettext backend module from step 2. An optional
    `sigils: [domain: "errors"]` pins the Gettext domain for every `~t` in this module.
    """
  },
  %{
    title: "Step 5 — set the locale per-request / per-process",
    code: ~S'''
    Localize.put_locale(:de)
    Localize.with_locale(:fr, fn -> render_email_template() end)
    ''',
    prose: """
    `Gettext` reads the current locale from `Gettext.get_locale/1`, which Localize keeps in
    sync with `Localize.get_locale/0`. `put_locale/1` sets it for the rest of the process;
    `with_locale/2` sets it for the duration of a function call. Phoenix users normally set
    it in a plug (see `translate_phoenix`); LiveView users set it in `on_mount` (see
    `translate_liveview`).
    """
  }
]

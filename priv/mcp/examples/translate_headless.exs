# Translating messages in a headless app — no Phoenix, no
# Plug, no request lifecycle. Common cases: a library, a CLI,
# a CI/build tool, a background job.
#
# Assumes you've already done `translate_setup`. The patterns
# below focus on the runtime side: where to set the locale, how
# the `~t` sigil composes with normal Elixir control flow, and
# how to handle locale fallback when a translation is missing.

[
  %{
    title: "A standalone module using ~t",
    filename: "lib/my_app/notifications.ex",
    code: ~S'''
    defmodule MyApp.Notifications do
      use Localize.Message.Sigils, backend: MyApp.Gettext

      @spec greeting(String.t()) :: String.t()
      def greeting(name), do: ~t"Hello, #{name}!"

      @spec inventory(non_neg_integer()) :: String.t()
      def inventory(count) do
        ~t"""
        .input {$count :integer}
        .match $count
        0   {{Out of stock.}}
        1   {{One in stock.}}
        *   {{#{count = count} in stock.}}
        """
      end
    end
    ''',
    prose: """
    Every module that uses `~t` opts in once with `use Localize.Message.Sigils, backend: …`.
    The sigil resolves against `MyApp.Gettext` at compile time and against
    `Localize.get_locale/0` at runtime.
    """
  },
  %{
    title: "Setting the locale on a per-function basis",
    code: ~S'''
    Localize.with_locale(:de, fn ->
      MyApp.Notifications.greeting("Greta")
    end)
    #=> "Hallo, Greta!"
    ''',
    prose: """
    `with_locale/2` is the right primitive for non-request-bound code — background jobs,
    email generators, exports. It restores the previous locale even if the function raises.
    """
  },
  %{
    title: "Setting the application-wide default",
    code: ~S'''
    # In config/config.exs (compile-time)
    config :localize, default_locale: :de

    # Or at runtime
    Localize.put_default_locale(:de)
    ''',
    prose: """
    Every process inherits the application-wide default until it overrides via
    `put_locale/1` / `with_locale/2`. For CLI tools that read `LANG` from the environment,
    Localize already does the right thing — `LANG=de_DE.UTF-8 mix run` defaults to `:de`.
    """
  },
  %{
    title: "Handling a missing translation",
    code: ~S'''
    defmodule MyApp.Emails do
      use Localize.Message.Sigils, backend: MyApp.Gettext

      def welcome(name) do
        # If `:fr` has no translation for this msgid, Gettext falls back
        # to the msgid itself (the source-language English string).
        # That's almost always the desired behaviour.
        ~t"Welcome, #{name}!"
      end
    end
    ''',
    prose: """
    Gettext's default fallback is: locale-specific PO → domain default → msgid. If you want a
    different policy (e.g. raise on missing), configure the backend with
    `allowed_locales:` and `:default_locale`. See the Gettext docs for the full matrix.
    """
  },
  %{
    title: "Formatting numbers / dates inside a translated message",
    code: ~S'''
    defmodule MyApp.Receipts do
      use Localize.Message.Sigils, backend: MyApp.Gettext

      def total(amount, currency) do
        # MF2 has built-in :number, :currency, :date, :time functions that
        # translators can re-order per locale. The bindings flow through
        # Localize's formatters automatically.
        ~t"""
        Your total is {#{amount = amount} :currency currency=#{currency = currency}}.
        """
      end
    end
    ''',
    prose: """
    MF2 functions inside `~t` route through `Localize.Number`, `Localize.Date`, etc., so the
    output respects the locale's grouping separator, currency symbol position, calendar
    system, and so on. No extra wiring required.
    """
  },
  %{
    title: "Calling `Localize.Message.format/3` with a runtime msgid",
    code: ~S'''
    msgid = load_from_database()
    {:ok, formatted} = Localize.Message.format(msgid, %{"name" => "World"})
    ''',
    prose: """
    Use `Localize.Message.format/3` (the runtime API) when the msgid isn't a literal at
    compile time — content loaded from a CMS, a database, or constructed programmatically.
    Note this skips Gettext lookup; if you want translation *and* runtime msgids, look up
    the translated string yourself via your Gettext backend's domain accessors and then
    pass the result to `format/3`.
    """
  }
]

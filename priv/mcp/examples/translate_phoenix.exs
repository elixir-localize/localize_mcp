# Translating messages in a Phoenix application (HTML + JSON,
# MVC-style controllers and templates — not LiveView).
#
# Assumes you've done `translate_setup` and have the
# `localize_web` package as a dependency.
#
# The story has three parts:
#   1. Pick the request locale (plug).
#   2. Use `~t` in your templates and controllers.
#   3. Render messages that contain markup with the
#      `Localize.HTML.Message` component.

[
  %{
    title: "Step 1 — install the locale-detection plug",
    filename: "lib/my_app_web/endpoint.ex",
    code: ~S'''
    defmodule MyAppWeb.Endpoint do
      use Phoenix.Endpoint, otp_app: :my_app

      # ... other plugs ...

      plug Localize.Plug.PutLocale,
        sources: [
          # Try each source in order. First non-nil wins.
          :query,           # ?locale=de
          :path,            # /de/users/...
          :session,         # whatever PutSession last stored
          :accept_language, # Accept-Language: de;q=0.9, en;q=0.5
          :cookie,          # cookie named "locale"
          :default          # falls back to Localize.default_locale/0
        ]

      plug Localize.Plug.PutSession
    end
    ''',
    prose: """
    `Localize.Plug.PutLocale` walks the listed sources, picks the first valid locale, and
    calls `Localize.put_locale/1` for the rest of the request. `PutSession` persists that
    choice so subsequent requests start at the user's preferred locale even without a
    query string.
    """
  },
  %{
    title: "Step 2 — use ~t in a controller",
    filename: "lib/my_app_web/controllers/page_controller.ex",
    code: ~S'''
    defmodule MyAppWeb.PageController do
      use MyAppWeb, :controller
      use Localize.Message.Sigils, backend: MyApp.Gettext

      def show(conn, %{"id" => id}) do
        page = Pages.get!(id)
        render(conn, :show, page: page, title: ~t"Welcome, #{@current_user.name}!")
      end
    end
    ''',
    prose: """
    Note the `@current_user.name` interpolation. The `~t` sigil derives a binding name
    (`current_user_name`) automatically — the msgid stored in `.po` is
    `"Welcome, {$current_user_name}!"`.
    """
  },
  %{
    title: "Step 3 — use ~t in a HEEx template",
    filename: "lib/my_app_web/controllers/page_html/show.html.heex",
    code: ~S'''
    <h1>{~t"Welcome to #{@page.title}!"}</h1>

    <p>{~t"You have #{count = length(@items)} items in your cart."}</p>
    ''',
    prose: """
    In HEEx, `~t` returns a plain binary, so interpolate it with `{...}` like any other
    value. For correctness with HTML special characters, see the next step.
    """
  },
  %{
    title: "Step 4 — translations that contain markup",
    filename: "lib/my_app_web/controllers/page_html/show.html.heex",
    code: ~S'''
    <.live_component module={Localize.HTML.Message}
                     msgid={~t"Read our {#link href=|/terms|}terms of service{/link}."} />
    ''',
    prose: """
    When a translation has inline emphasis, links, or other HTML markup, use the
    `Localize.HTML.Message` component instead of plain `~t` interpolation. The component
    parses the MF2 markup tags (`{#link …}…{/link}`) and renders them as Phoenix
    components — `<.link href=…>` in this case — so the structure survives translation
    even when translators reorder it per locale.

    Built-in markup tags: `bold` / `strong`, `italic` / `emphasis` / `em`, `code`,
    `link`, `br`. Custom tags can be registered globally
    (`config :localize_web, :mf2_markup, components: %{...}`) or per-component via the
    `:components` attribute.
    """
  },
  %{
    title: "Step 5 — locale-aware routes (optional)",
    filename: "lib/my_app_web/router.ex",
    code: ~S'''
    defmodule MyAppWeb.Router do
      use Phoenix.Router
      use Localize.Routes

      scope "/", MyAppWeb do
        pipe_through :browser

        localize do
          get "/about", PageController, :about
          get "/products", ProductController, :index
        end
      end
    end
    ''',
    prose: """
    `Localize.Routes` translates the path segments at compile time using Gettext. With the
    `de` locale's PO containing `msgid "/about"` / `msgstr "/ueber-uns"`, the German URL
    becomes `/de/ueber-uns` automatically. Use the `~q` sigil from `Localize.VerifiedRoutes`
    in templates so the compiler verifies the path matches the locale.
    """
  },
  %{
    title: "Step 6 — locale switcher component",
    filename: "lib/my_app_web/components/locale_switcher.html.heex",
    code: ~S'''
    <%= Localize.HTML.Locale.select(:locale_form, :locale,
          selected: Localize.get_locale().cldr_locale_id,
          locales: [:en, :de, :fr, :ja]) %>
    ''',
    prose: """
    `Localize.HTML.Locale.select/3` (from `localize_web`) renders a `<select>` whose
    options are display-name-localised per the current locale (German users see
    "Deutsch / Englisch / Französisch / Japanisch"). Wire its `phx-change` to a
    controller action or LiveView event that calls `Localize.put_locale/1`.
    """
  }
]

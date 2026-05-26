# Translating messages in Phoenix LiveView.
#
# Assumes you've done `translate_setup` and have `localize_web`
# as a dependency. The Phoenix MVC patterns from
# `translate_phoenix` (the locale-detection plug, `~t` in
# templates, the markup component) all apply unchanged. This
# capability covers the LiveView-specific bits:
#
#   1. Carrying the locale across the initial render and the
#      WebSocket connection.
#   2. Switching locale mid-session without a full reload.
#   3. Re-rendering when the locale changes.

[
  %{
    title: "Step 1 — pick the locale at mount time",
    filename: "lib/my_app_web/live/page_live.ex",
    code: ~S'''
    defmodule MyAppWeb.PageLive do
      use MyAppWeb, :live_view
      use Localize.Message.Sigils, backend: MyApp.Gettext

      on_mount {Localize.Plug, :put_locale}

      def render(assigns) do
        ~H"""
        <h1>{~t"Welcome, #{@current_user.name}!"}</h1>
        """
      end
    end
    ''',
    prose: """
    `Localize.Plug.put_locale/1` is an `on_mount` callback that pulls the locale from the
    session (which `Localize.Plug.PutSession` stored during the initial HTTP request) and
    calls `Localize.put_locale/1` in the LiveView process. This makes the locale available
    for both the dead render and the subsequent WebSocket-driven re-renders.
    """
  },
  %{
    title: "Step 2 — locale switcher in a LiveView",
    filename: "lib/my_app_web/live/page_live.ex",
    code: ~S'''
    def render(assigns) do
      ~H"""
      <form phx-change="set_locale">
        <%= Localize.HTML.Locale.select(:locale_form, :locale,
              selected: Localize.get_locale().cldr_locale_id,
              locales: [:en, :de, :fr]) %>
      </form>

      <h1>{~t"Welcome, #{@current_user.name}!"}</h1>
      """
    end

    def handle_event("set_locale", %{"locale_form" => %{"locale" => locale}}, socket) do
      Localize.put_locale(locale)
      {:noreply, socket}
    end
    ''',
    prose: """
    Setting the locale on the LiveView process changes what subsequent `~t` calls return.
    LiveView re-renders the template automatically after `handle_event/3` so the user sees
    the new translation immediately. No `assign` change is required — `~t` reads the
    process-dictionary locale on every call.

    To *persist* the choice across reloads, also call `MyAppWeb.Endpoint.broadcast/3` or
    push a JS hook event that updates the cookie / session.
    """
  },
  %{
    title: "Step 3 — translations that contain HTML markup",
    filename: "lib/my_app_web/live/page_live.ex",
    code: ~S'''
    def render(assigns) do
      ~H"""
      <.live_component
        module={Localize.HTML.Message}
        msgid={~t"Read our {#link navigate=|/terms|}terms of service{/link}."} />
      """
    end
    ''',
    prose: """
    `Localize.HTML.Message` works identically in LiveView and in MVC templates. Inside a
    LiveView the rendered `<.link>` uses Phoenix's `navigate` attribute by default for
    same-LiveView navigation; `patch` and `href` are also accepted.
    """
  },
  %{
    title: "Step 4 — pluralised translations driven by an assign",
    filename: "lib/my_app_web/live/cart_live.ex",
    code: ~S'''
    defmodule MyAppWeb.CartLive do
      use MyAppWeb, :live_view
      use Localize.Message.Sigils, backend: MyApp.Gettext

      on_mount {Localize.Plug, :put_locale}

      def mount(_params, _session, socket) do
        {:ok, assign(socket, items: [])}
      end

      def render(assigns) do
        ~H"""
        <p>
          {~t"""
           .input {$count :integer}
           .match $count
           0   {{Your cart is empty.}}
           1   {{One item in your cart.}}
           *   {{#{count = length(@items)} items in your cart.}}
           """}
        </p>
        """
      end
    end
    ''',
    prose: """
    Multi-line `~t` heredocs work the same way as single-line. The MF2 selector picks the
    right variant per render. The English source above produces three msgids in `.po`;
    translators get to pick the categories their language needs (Russian uses :one /
    :few / :many / :other, for example — MF2's CLDR-aligned plural rules know about that).
    """
  },
  %{
    title: "Step 5 — re-render when an external process changes locale",
    code: ~S'''
    # In an on_mount or mount callback:
    Phoenix.PubSub.subscribe(MyApp.PubSub, "user:#{user_id}:locale")

    # When a sibling tab / device updates the locale:
    Phoenix.PubSub.broadcast(MyApp.PubSub, "user:#{user_id}:locale", {:locale, :de})

    # Handle it in the LiveView:
    def handle_info({:locale, locale}, socket) do
      Localize.put_locale(locale)
      {:noreply, socket}
    end
    ''',
    prose: """
    If a user changes the locale in one browser tab, sibling tabs and devices won't pick
    that up without help. PubSub is the standard way: broadcast `{:locale, :xx}` to a
    per-user topic when the user's locale changes (in your controller, in a callback,
    wherever), and each LiveView mounted under that topic updates its own process locale
    on receipt. LiveView's re-render hooks the rest.
    """
  }
]

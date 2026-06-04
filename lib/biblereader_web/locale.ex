defmodule BibleReaderWeb.Locale do
  @moduledoc """
  LiveView helpers for locale assignment.
  """
  use BibleReaderWeb, :verified_routes

  import Phoenix.Component

  alias BibleReader.Locale, as: AppLocale

  @doc """
  `on_mount` callback: assigns `:locale` and sets Gettext locale for the LiveView process.
  """
  def on_mount(:set_locale, _params, session, socket) do
    user =
      socket.assigns[:current_user] ||
        user_from_session(session)

    locale =
      cond do
        user ->
          AppLocale.normalize(user.locale)

        session["locale"] ->
          AppLocale.normalize(session["locale"])

        true ->
          AppLocale.default()
      end

    Gettext.put_locale(BibleReaderWeb.Gettext, locale)

    socket =
      socket
      |> assign(:locale, locale)
      |> then(fn s -> if user, do: assign(s, :current_user, user), else: s end)

    {:cont, socket}
  end

  defp user_from_session(%{"user_token" => token}) when is_binary(token) do
    BibleReader.Accounts.get_user_by_session_token(token)
  end

  defp user_from_session(_), do: nil

  @doc "Builds a path to switch locale via LocaleController."
  def switch_path(locale, return_to \\ "/read") do
    ~p"/locale/#{AppLocale.normalize(locale)}?#{%{return_to: return_to}}"
  end
end

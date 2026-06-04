defmodule BibleReaderWeb.LocaleController do
  use BibleReaderWeb, :controller

  alias BibleReader.Accounts
  alias BibleReader.Locale
  alias BibleReaderWeb.Plugs.Locale, as: LocalePlug

  def update(conn, %{"locale" => locale}) do
    locale = Locale.normalize(locale)

    if conn.assigns[:current_user] do
      Accounts.update_user_reading_profile(conn.assigns.current_user, %{locale: locale})
    end

    conn =
      conn
      |> put_session(LocalePlug.session_key(), locale)
      |> LocalePlug.put_locale(locale)

    redirect(conn, to: redirect_to(conn))
  end

  defp redirect_to(conn) do
    case conn.query_params["return_to"] do
      path when is_binary(path) and path != "" -> path
      _ -> ~p"/read"
    end
  end
end

defmodule BibleReaderWeb.Plugs.LocaleTest do
  use BibleReaderWeb.ConnCase, async: true

  alias BibleReaderWeb.Plugs.Locale

  setup %{conn: conn} do
    {:ok, conn: Phoenix.ConnTest.init_test_session(conn, %{})}
  end

  test "sets locale from Accept-Language de", %{conn: conn} do
    conn =
      conn
      |> Plug.Conn.put_req_header("accept-language", "de-DE,de;q=0.9")
      |> Locale.call([])

    assert conn.assigns.locale == "de"
    assert get_session(conn, :locale) == "de"
  end

  test "logged-in user locale overrides session", %{conn: conn} do
    user = BibleReader.AccountsFixtures.user_fixture(%{locale: "de"})

    conn =
      conn
      |> Plug.Conn.put_session(:locale, "en")
      |> assign(:current_user, user)
      |> Locale.call([])

    assert conn.assigns.locale == "de"
  end
end

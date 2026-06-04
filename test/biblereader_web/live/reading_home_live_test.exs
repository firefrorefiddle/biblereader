defmodule BibleReaderWeb.ReadingHomeLiveTest do
  use BibleReaderWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  alias BibleReader.AccountsFixtures

  setup %{conn: conn} do
    user = AccountsFixtures.user_fixture(%{locale: "de"})
    %{conn: log_in_user(conn, user), user: user}
  end

  test "renders German dashboard for de locale", %{conn: conn} do
    {:ok, _view, html} = live(conn, ~p"/read")

    assert html =~ "Heute"
    refute html =~ ">Today<"
  end
end

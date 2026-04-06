defmodule BibleReaderWeb.BibleLiveTest do
  use BibleReaderWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  import BibleReader.AccountsFixtures
  alias BibleReader.ScriptureFixtures

  setup %{conn: conn} do
    ScriptureFixtures.book_and_chapter_fixture()
    user = user_fixture()
    %{conn: log_in_user(conn, user)}
  end

  test "lists stats and log read", %{conn: conn} do
    {:ok, lv, html} = live(conn, ~p"/read")

    assert html =~ "Reading stats"
    assert html =~ "Rolling window"

    lv
    |> element("button", "Log read")
    |> render_click()

    html = render(lv)
    assert html =~ "1×"
  end
end

defmodule BibleReaderWeb.ReadingHistoryLiveTest do
  use BibleReaderWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  alias BibleReader.AccountsFixtures
  alias BibleReader.ReadingPlan
  alias BibleReader.Scripture
  alias BibleReader.ScriptureFixtures

  describe "authenticated" do
    setup %{conn: conn} do
      %{book: book, chapter: chapter} = ScriptureFixtures.book_and_chapter_fixture()
      user = AccountsFixtures.user_fixture(%{locale: "en"})
      {:ok, _} = ReadingPlan.log_chapter_read(user, chapter.id)
      %{conn: log_in_user(conn, user), user: user, book: book, chapter: chapter}
    end

    test "renders reading history with logged chapter", %{conn: conn, book: book} do
      {:ok, _view, html} = live(conn, ~p"/read/history")

      assert html =~ "Reading history"
      assert html =~ Scripture.book_display_name(book, "en")
      assert html =~ "Today"
    end

    test "renders German page for de locale", %{chapter: chapter} do
      user = AccountsFixtures.user_fixture(%{locale: "de"})
      {:ok, _} = ReadingPlan.log_chapter_read(user, chapter.id)

      conn = log_in_user(build_conn(), user)
      {:ok, _view, html} = live(conn, ~p"/read/history")

      assert html =~ "Leseverlauf"
      refute html =~ ">Reading history<"
    end
  end

  test "redirects guests to log in", %{conn: conn} do
    assert {:error, {:redirect, %{to: path}}} = live(conn, ~p"/read/history")
    assert path =~ "/users/log_in"
  end
end

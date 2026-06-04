defmodule BibleReaderWeb.BookLiveTest do
  use BibleReaderWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  import BibleReader.AccountsFixtures
  alias BibleReader.ScriptureFixtures

  setup %{conn: conn} do
    %{chapter: chapter, book: book} = ScriptureFixtures.book_and_chapter_fixture()
    user = user_fixture()
    %{conn: log_in_user(conn, user), chapter: chapter, book: book}
  end

  test "renders book grid", %{conn: conn, book: book} do
    {:ok, _lv, html} = live(conn, ~p"/read/books/#{book.code}")
    assert html =~ book.name
    assert html =~ "Chapters"
    assert html =~ "Legend"
  end

  test "chapter view reachable from book", %{conn: conn, book: book} do
    {:ok, _lv, html} = live(conn, ~p"/read/books/#{book.code}/1")
    assert html =~ book.name
    assert html =~ "Mark as read"
  end
end

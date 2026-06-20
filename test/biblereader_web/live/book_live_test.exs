defmodule BibleReaderWeb.BookLiveTest do
  use BibleReaderWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  import BibleReader.AccountsFixtures
  alias BibleReader.ReadingPlan
  alias BibleReader.ScriptureFixtures

  setup %{conn: conn} do
    %{chapter: chapter, book: book} = ScriptureFixtures.book_and_chapter_fixture()
    user = user_fixture()
    %{conn: log_in_user(conn, user), chapter: chapter, book: book, user: user}
  end

  test "renders book grid", %{conn: conn, book: book} do
    {:ok, _lv, html} = live(conn, ~p"/read/books/#{book.code}")
    assert html =~ book.name
    assert html =~ "Chapters"
    assert html =~ "Legend"
    assert html =~ "Mark as read"
  end

  test "log read from book grid without opening chapter", %{
    conn: conn,
    book: book,
    chapter: chapter,
    user: user
  } do
    {:ok, lv, html} = live(conn, ~p"/read/books/#{book.code}")
    refute html =~ "1 of 1 chapters read"

    html =
      lv
      |> element(
        "button[phx-value-chapter-id=\"#{chapter.id}\"][aria-label=\"Mark #{book.name} #{chapter.chapter_number} as read\"]"
      )
      |> render_click()

    assert html =~ "Chapter marked as read"
    refute html =~ "Success!"
    assert html =~ "Undo"
    assert html =~ "1 of 1 chapters read"
    assert ReadingPlan.read_counts_by_chapter_id(user.id)[chapter.id] == 1
  end

  test "undo read from book grid flash", %{
    conn: conn,
    book: book,
    chapter: chapter,
    user: user
  } do
    {:ok, lv, _} = live(conn, ~p"/read/books/#{book.code}")

    lv
    |> element(
      "button[phx-value-chapter-id=\"#{chapter.id}\"][aria-label=\"Mark #{book.name} #{chapter.chapter_number} as read\"]"
    )
    |> render_click()

    html =
      lv
      |> element("#flash-chapter-read button", "Undo")
      |> render_click()

    refute html =~ "flash-chapter-read"
    refute html =~ "1 of 1 chapters read"
    refute Map.has_key?(ReadingPlan.read_counts_by_chapter_id(user.id), chapter.id)
  end

  test "chapter view reachable from book", %{conn: conn, book: book} do
    {:ok, _lv, html} = live(conn, ~p"/read/books/#{book.code}/1")
    assert html =~ book.name
    assert html =~ "Mark as read"
  end
end

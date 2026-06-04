defmodule BibleReaderWeb.ChapterLiveTest do
  use BibleReaderWeb.ConnCase, async: false

  import Phoenix.LiveViewTest

  import BibleReader.AccountsFixtures
  alias BibleReader.Scripture
  alias BibleReader.ScriptureTextFixtures

  setup %{conn: conn} do
    ScriptureTextFixtures.import_genesis_snippet!()
    book = Scripture.get_book_by_code("GEN")
    chapter = Scripture.get_chapter_by_code_and_number("GEN", 1)
    user = user_fixture()
    %{conn: log_in_user(conn, user), chapter: chapter, book: book, user: user}
  end

  test "renders imported scripture text", %{conn: conn, book: book} do
    {:ok, _lv, html} = live(conn, ~p"/read/books/#{book.code}/1")
    assert html =~ "Im Anfang schuf Gott"
    assert html =~ "Im Hebr."
    assert html =~ "Footnotes"
  end

  test "renders chapter view", %{conn: conn, book: book} do
    {:ok, _lv, html} = live(conn, ~p"/read/books/#{book.code}/1")
    assert html =~ "#{book.name}"
    assert html =~ "Mark as read"
    assert html =~ "Elberfelder"
    assert html =~ "Notes"
  end

  test "log read from chapter page", %{conn: conn, book: book, chapter: chapter} do
    {:ok, lv, _} = live(conn, ~p"/read/books/#{book.code}/#{chapter.chapter_number}")
    html = lv |> element("button", "Mark as read") |> render_click()
    assert html =~ "Read count: 1"
  end

  test "save note", %{conn: conn, book: book, chapter: chapter, user: user} do
    {:ok, lv, _} = live(conn, ~p"/read/books/#{book.code}/#{chapter.chapter_number}")

    lv
    |> form("#chapter-note-form", note: %{body: "My reflection"})
    |> render_submit()

    assert render(lv) =~ "Saved"
    note = BibleReader.Notes.get_note(user.id, chapter.id)
    assert note.body == "My reflection"
  end
end

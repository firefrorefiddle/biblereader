defmodule BibleReaderWeb.ChapterLiveTest do
  use BibleReaderWeb.ConnCase, async: false

  import Phoenix.LiveViewTest

  import BibleReader.AccountsFixtures
  alias BibleReader.Scripture
  alias BibleReader.ScriptureTextFixtures

  setup %{conn: conn} do
    ScriptureTextFixtures.import_genesis_snippet!()
    book = Scripture.get_book_by_code("GEN")

    for n <- 2..3 do
      %BibleReader.Scripture.Chapter{}
      |> BibleReader.Scripture.Chapter.changeset(%{book_id: book.id, chapter_number: n})
      |> BibleReader.Repo.insert!()
    end

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

  test "log read from chapter page", %{conn: conn, book: book, chapter: chapter, user: user} do
    {:ok, lv, _} = live(conn, ~p"/read/books/#{book.code}/#{chapter.chapter_number}")
    html = lv |> element("button", "Mark as read") |> render_click()
    assert html =~ "Read count: 1"
    assert html =~ "Undo"
    refute html =~ "Success!"
    assert BibleReader.ReadingPlan.read_counts_by_chapter_id(user.id)[chapter.id] == 1
  end

  test "undo read from chapter page flash", %{
    conn: conn,
    book: book,
    chapter: chapter,
    user: user
  } do
    {:ok, lv, _} = live(conn, ~p"/read/books/#{book.code}/#{chapter.chapter_number}")

    lv |> element("button", "Mark as read") |> render_click()

    html =
      lv
      |> element("#flash-chapter-read button", "Undo")
      |> render_click()

    assert html =~ "Not read yet"
    refute html =~ "flash-chapter-read"
    refute Map.has_key?(BibleReader.ReadingPlan.read_counts_by_chapter_id(user.id), chapter.id)
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

  test "shows next chapter link on first chapter", %{conn: conn, book: book} do
    ch2 = Scripture.get_chapter_by_code_and_number("GEN", 2)

    {:ok, _lv, html} = live(conn, ~p"/read/books/#{book.code}/1")

    assert html =~ ~s(href="/read/books/GEN/2")
    refute html =~ ~s(aria-label="Previous chapter)
    assert html =~ "Genesis 2"
    assert ch2
  end

  test "shows previous and next links on middle chapter", %{conn: conn, book: book} do
    {:ok, _lv, html} = live(conn, ~p"/read/books/#{book.code}/2")

    assert html =~ ~s(href="/read/books/GEN/1")
    assert html =~ ~s(href="/read/books/GEN/3")
    assert html =~ "← Genesis 1"
    assert html =~ "Genesis 3"
  end
end

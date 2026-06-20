defmodule BibleReaderWeb.BibleOverviewLiveTest do
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

  test "renders bible overview with books and legend", %{conn: conn, book: book} do
    {:ok, _lv, html} = live(conn, ~p"/read/bible")

    assert html =~ "Bible overview"
    assert html =~ book.name
    assert html =~ "Legend"
    assert html =~ "Expand all"
    assert html =~ "Collapse all"
  end

  test "expands book section and logs read from grid", %{
    conn: conn,
    book: book,
    chapter: chapter,
    user: user
  } do
    {:ok, lv, html} = live(conn, ~p"/read/bible")
    refute html =~ "Mark #{book.name} #{chapter.chapter_number} as read"

    html =
      lv
      |> element("button[phx-click=\"toggle_book\"][phx-value-code=\"#{book.code}\"]")
      |> render_click()

    assert html =~ "Mark #{book.name} #{chapter.chapter_number} as read"

    html =
      lv
      |> element(
        "button[phx-value-chapter-id=\"#{chapter.id}\"][aria-label=\"Mark #{book.name} #{chapter.chapter_number} as read\"]"
      )
      |> render_click()

    assert html =~ "Chapter marked as read"
    assert html =~ "1 of 1 chapters read"
    assert ReadingPlan.read_counts_by_chapter_id(user.id)[chapter.id] == 1
  end

  test "renders German overview for de locale" do
    user = user_fixture(%{locale: "de"})
    conn = log_in_user(build_conn(), user)

    {:ok, _lv, html} = live(conn, ~p"/read/bible")

    assert html =~ "Bibel-Übersicht"
    refute html =~ ">Bible overview<"
  end
end

defmodule BibleReaderWeb.ReadingHomeLiveTest do
  use BibleReaderWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  import BibleReader.AccountsFixtures
  alias BibleReader.ScriptureFixtures

  setup %{conn: conn} do
    %{chapter: chapter, book: book} = ScriptureFixtures.book_and_chapter_fixture()
    user = user_fixture()
    %{conn: log_in_user(conn, user), user: user, chapter: chapter, book: book}
  end

  test "renders dashboard", %{conn: conn} do
    {:ok, _lv, html} = live(conn, ~p"/read")
    assert html =~ "Today"
    assert html =~ "Progress"
    assert html =~ "Books"
  end

  test "shows continue reading after log", %{conn: conn, user: user, chapter: chapter, book: book} do
    alias BibleReader.Scripture.Chapter

    {:ok, ch2} =
      %Chapter{}
      |> Chapter.changeset(%{book_id: book.id, chapter_number: 2})
      |> BibleReader.Repo.insert()

    assert {:ok, _} = BibleReader.ReadingPlan.log_chapter_read(user, chapter.id)

    {:ok, _lv, html} = live(conn, ~p"/read")
    assert html =~ "Continue reading"
    assert html =~ book.name
    assert html =~ Integer.to_string(ch2.chapter_number)
  end

  test "toggle more stats", %{conn: conn} do
    {:ok, lv, _} = live(conn, ~p"/read")
    html = lv |> element("button", "More stats") |> render_click()
    assert html =~ "Distinct chapters read"
    assert render(lv) =~ "Hide stats"
  end
end

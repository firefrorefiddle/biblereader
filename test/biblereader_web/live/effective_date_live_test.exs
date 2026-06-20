defmodule BibleReaderWeb.EffectiveDateLiveTest do
  use BibleReaderWeb.ConnCase, async: false

  import Phoenix.LiveViewTest

  alias BibleReader.AccountsFixtures
  alias BibleReader.ReadingPlan
  alias BibleReader.ReadingPlan.{EffectiveDate, RelativeTime}
  alias BibleReader.Scripture
  alias BibleReader.ScriptureFixtures
  alias BibleReaderWeb.EffectiveDate, as: EffectiveDateUI

  setup %{conn: conn} do
    %{book: book, chapter: chapter} = ScriptureFixtures.book_and_chapter_fixture()
    user = AccountsFixtures.user_fixture()
    %{conn: log_in_user(conn, user), user: user, book: book, chapter: chapter}
  end

  test "picker offers 30 selectable dates", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/read")

    html = view |> element("button", "Set effective date") |> render_click()

    assert html =~ "within the last 30 days"
    assert Regex.scan(~r/name="date" value="/, html) |> length() == 30
  end

  test "opens picker when Set effective date is clicked", %{conn: conn} do
    {:ok, view, html} = live(conn, ~p"/read")

    refute html =~ "id=\"effective-date-picker\""

    html = view |> element("button", "Set effective date") |> render_click()

    assert html =~ "id=\"effective-date-picker\""
    assert html =~ "Log chapters as if you read them"
    assert html =~ "Today (default)"
    assert html =~ "Apply"
  end

  test "closes picker when Cancel is clicked", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/read")

    view |> element("button", "Set effective date") |> render_click()

    html = view |> element("#effective-date-picker button", "Cancel") |> render_click()

    refute html =~ "id=\"effective-date-picker\""
  end

  test "shows banner when effective date is set", %{conn: conn} do
    today = RelativeTime.today_in_zone("Etc/UTC")
    past = Date.add(today, -2)
    past_label = EffectiveDate.format_long(past, "en")

    conn =
      conn
      |> Phoenix.ConnTest.init_test_session(%{})
      |> Plug.Conn.put_session(EffectiveDateUI.session_key(), Date.to_iso8601(past))

    {:ok, _view, html} = live(conn, ~p"/read")

    assert html =~ "Logging reads for:"
    assert html =~ past_label
    assert html =~ "Back to today"
    assert html =~ "Set effective date"
  end

  test "set effective date, log read, appears under correct day on history", %{
    conn: conn,
    book: book,
    chapter: chapter,
    user: user
  } do
    today = RelativeTime.today_in_zone(user.timezone)
    past = Date.add(today, -3)
    past_label = EffectiveDate.format_long(past, "en")
    chapter_path = ~p"/read/books/#{book.code}/#{chapter.chapter_number}"

    conn =
      post(conn, ~p"/read/effective_date", %{
        "date" => Date.to_iso8601(past),
        "return_to" => chapter_path
      })

    conn = get(conn, redirected_to(conn))
    {:ok, view, html} = live(conn, chapter_path)

    assert html =~ "Logging reads for:"
    assert html =~ past_label

    html =
      view
      |> element("button", "Mark as read")
      |> render_click()

    assert html =~ "Read count: 1"
    assert ReadingPlan.read_counts_by_chapter_id(user.id)[chapter.id] == 1

    read_at = Map.fetch!(ReadingPlan.last_read_at_by_chapter_id(user.id), chapter.id)
    assert RelativeTime.date_in_zone(read_at, user.timezone) == past

    {:ok, _history_view, history_html} = live(conn, ~p"/read/history")

    assert history_html =~ past_label
    assert history_html =~ Scripture.book_display_name(book, "en")
    refute history_html =~ ">Today<"
  end

  test "clear effective date hides banner", %{conn: conn} do
    today = RelativeTime.today_in_zone("Etc/UTC")
    past = Date.add(today, -1)

    conn =
      conn
      |> Phoenix.ConnTest.init_test_session(%{})
      |> Plug.Conn.put_session(EffectiveDateUI.session_key(), Date.to_iso8601(past))

    conn =
      post(conn, ~p"/read/effective_date", %{
        "date" => "today",
        "return_to" => ~p"/read"
      })

    conn = get(conn, redirected_to(conn))
    {:ok, _view, html} = live(conn, ~p"/read")

    refute html =~ "Logging reads for:"
  end
end

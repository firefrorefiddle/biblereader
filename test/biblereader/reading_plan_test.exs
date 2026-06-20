defmodule BibleReader.ReadingPlanTest do
  use BibleReader.DataCase, async: true

  import BibleReader.AccountsFixtures

  alias BibleReader.Accounts
  alias BibleReader.ReadingPlan
  alias BibleReader.ReadingPlan.RelativeTime
  alias BibleReader.ReadingPlan.EffectiveDate
  alias BibleReader.Repo
  alias BibleReader.Scripture.Chapter
  alias BibleReader.ScriptureFixtures

  setup do
    %{book: book, chapter: chapter} = ScriptureFixtures.book_and_chapter_fixture()
    user = user_fixture()
    %{user: user, chapter: chapter, book: book}
  end

  test "log_chapter_read inserts an event", %{user: user, chapter: chapter} do
    assert {:ok, read} = ReadingPlan.log_chapter_read(user, chapter.id)
    assert read.user_id == user.id
    assert read.chapter_id == chapter.id
  end

  test "undo_last_chapter_read removes the most recent event", %{user: user, chapter: chapter} do
    old =
      DateTime.utc_now()
      |> DateTime.add(-3600, :second)
      |> DateTime.truncate(:second)

    assert {:ok, _} = ReadingPlan.log_chapter_read(user, chapter.id, old)
    assert {:ok, latest} = ReadingPlan.log_chapter_read(user, chapter.id)

    assert {:ok, deleted} = ReadingPlan.undo_last_chapter_read(user, chapter.id)
    assert deleted.id == latest.id
    assert ReadingPlan.read_counts_by_chapter_id(user.id)[chapter.id] == 1

    assert {:ok, _} = ReadingPlan.undo_last_chapter_read(user, chapter.id)
    refute Map.has_key?(ReadingPlan.read_counts_by_chapter_id(user.id), chapter.id)
  end

  test "undo_last_chapter_read returns not_found when no events", %{user: user, chapter: chapter} do
    assert {:error, :not_found} = ReadingPlan.undo_last_chapter_read(user, chapter.id)
  end

  test "read_counts_by_chapter_id aggregates", %{user: user, chapter: chapter} do
    assert {:ok, _} = ReadingPlan.log_chapter_read(user, chapter.id)
    assert {:ok, _} = ReadingPlan.log_chapter_read(user, chapter.id)
    counts = ReadingPlan.read_counts_by_chapter_id(user.id)
    assert counts[chapter.id] == 2
  end

  test "last_read_at_by_chapter_id", %{user: user, chapter: chapter} do
    assert {:ok, read} = ReadingPlan.log_chapter_read(user, chapter.id)
    map = ReadingPlan.last_read_at_by_chapter_id(user.id)
    assert DateTime.compare(map[chapter.id], read.read_at) == :eq
  end

  test "read_events_for_chapter", %{user: user, chapter: chapter} do
    assert {:ok, _} = ReadingPlan.log_chapter_read(user, chapter.id)
    assert {:ok, _} = ReadingPlan.log_chapter_read(user, chapter.id)
    assert length(ReadingPlan.read_events_for_chapter(user.id, chapter.id)) == 2
  end

  test "chapters_read_in_window", %{user: user, chapter: chapter} do
    assert {:ok, _} = ReadingPlan.log_chapter_read(user, chapter.id)
    assert ReadingPlan.chapters_read_in_window(user, 7) >= 1
  end

  test "recent_read_events returns all events for user", %{
    user: user,
    chapter: chapter
  } do
    now = DateTime.utc_now() |> DateTime.truncate(:second)
    assert {:ok, _} = ReadingPlan.log_chapter_read(user, chapter.id, now)

    [event] = ReadingPlan.recent_read_events(user)
    assert event.chapter_id == chapter.id
    assert event.chapter.book.id == chapter.book_id
  end

  test "recent_read_events includes reads older than a week", %{user: user, chapter: chapter} do
    old =
      DateTime.utc_now()
      |> DateTime.add(-8 * 86_400, :second)
      |> DateTime.truncate(:second)

    assert {:ok, _} = ReadingPlan.log_chapter_read(user, chapter.id, old)

    events = ReadingPlan.recent_read_events(user)
    assert length(events) == 1
    assert hd(events).chapter_id == chapter.id
  end

  test "recent_read_events_by_day groups by user timezone day", %{user: user, chapter: chapter} do
    now = DateTime.utc_now() |> DateTime.truncate(:second)
    assert {:ok, _} = ReadingPlan.log_chapter_read(user, chapter.id, now)

    [day] = ReadingPlan.recent_read_events_by_day(user)
    assert day.day_label == :today
    assert length(day.events) == 1
    assert hd(day.events).chapter_id == chapter.id
  end

  test "recently_read_chapters", %{user: user, chapter: chapter, book: book} do
    assert {:ok, _} = ReadingPlan.log_chapter_read(user, chapter.id)
    [row] = ReadingPlan.recently_read_chapters(user, limit: 5)
    assert row.book.id == book.id
    assert row.chapter.id == chapter.id
    assert row.read_count == 1
  end

  test "continue_reading suggests next chapter", %{user: user, chapter: chapter, book: book} do
    {:ok, ch2} =
      %Chapter{}
      |> Chapter.changeset(%{book_id: book.id, chapter_number: 2})
      |> Repo.insert()

    assert {:ok, _} = ReadingPlan.log_chapter_read(user, chapter.id)
    user = Accounts.get_user!(user.id)

    assert %{book: ^book, chapter: next, last_read: _} = ReadingPlan.continue_reading(user)
    assert next.id == ch2.id
  end

  test "continue_reading when no reads suggests first chapter", %{user: user, book: book} do
    user = Accounts.get_user!(user.id)
    assert %{book: ^book, chapter: ch} = ReadingPlan.continue_reading(user)
    assert ch.chapter_number == 1
  end

  test "stats_for_user returns rolling window fields", %{user: user, chapter: chapter} do
    assert {:ok, _} = ReadingPlan.log_chapter_read(user, chapter.id)
    user = Accounts.get_user!(user.id)
    stats = ReadingPlan.stats_for_user(user, rolling_days: 30)
    assert stats.rolling_days == 30
    assert stats.chapters_read_in_window >= 1
    assert stats.distinct_chapters_read_at_least_once >= 1
    assert stats.total_chapters_in_scope >= 1
  end

  test "dashboard_pace_summary", %{user: user, chapter: chapter} do
    assert {:ok, _} = ReadingPlan.log_chapter_read(user, chapter.id)
    user = Accounts.get_user!(user.id)
    summary = ReadingPlan.dashboard_pace_summary(user)
    assert summary.chapters_in_window >= 1
    assert summary.has_pace
  end

  test "book_progress_for_user", %{user: user, chapter: chapter, book: book} do
    assert {:ok, _} = ReadingPlan.log_chapter_read(user, chapter.id)
    user = Accounts.get_user!(user.id)
    [row] = ReadingPlan.book_progress_for_user(user) |> Enum.filter(&(&1.book.id == book.id))
    assert row.chapters_read == 1
    assert row.total_chapters >= 1
    assert row.last_chapter_number == 1
  end

  test "bible_overview_for_user aggregates progress in one pass", %{
    user: user,
    chapter: chapter,
    book: book
  } do
    assert {:ok, _} = ReadingPlan.log_chapter_read(user, chapter.id)

    overview = ReadingPlan.bible_overview_for_user(user)
    assert overview.total_chapters >= 1
    assert overview.chapters_read >= 1

    section = Enum.find(overview.sections, &(&1.book.id == book.id))
    assert section.chapters_read == 1
    assert section.total_chapters >= 1
    assert Enum.any?(section.chapters, &(&1.id == chapter.id))
  end

  test "log with effective read_at groups in recent history", %{user: user, chapter: chapter} do
    today = RelativeTime.today_in_zone(user.timezone)
    past = Date.add(today, -2)
    read_at = EffectiveDate.read_at_for(past, user.timezone)

    assert {:ok, _} = ReadingPlan.log_chapter_read(user, chapter.id, read_at)

    days = ReadingPlan.recent_read_events_by_day(user)
    matching = Enum.find(days, fn day -> day.date == past end)
    assert matching
    assert hd(matching.events).chapter_id == chapter.id
  end

  test "RelativeTime label today", %{user: user} do
    now = DateTime.utc_now() |> DateTime.truncate(:second)
    assert RelativeTime.label(now, user.timezone) == :today
  end

  test "RelativeTime label_for_date and start_of_day_utc", %{user: user} do
    today = RelativeTime.today_in_zone(user.timezone)
    assert RelativeTime.label_for_date(today, user.timezone) == :today
    assert %DateTime{} = RelativeTime.start_of_day_utc(today, user.timezone)
  end

  test "age_bucket unread", %{user: user} do
    assert ReadingPlan.age_bucket(0, nil, user.timezone) == :unread
  end
end

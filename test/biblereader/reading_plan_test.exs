defmodule BibleReader.ReadingPlanTest do
  use BibleReader.DataCase, async: true

  import BibleReader.AccountsFixtures

  alias BibleReader.Accounts
  alias BibleReader.ReadingPlan
  alias BibleReader.ReadingPlan.RelativeTime
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

  test "RelativeTime label today", %{user: user} do
    now = DateTime.utc_now() |> DateTime.truncate(:second)
    assert RelativeTime.label(now, user.timezone) == "today"
  end

  test "age_bucket unread", %{user: user} do
    assert ReadingPlan.age_bucket(0, nil, user.timezone) == :unread
  end
end

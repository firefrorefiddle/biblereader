defmodule BibleReader.ReadingPlanTest do
  use BibleReader.DataCase, async: true

  import BibleReader.AccountsFixtures

  alias BibleReader.Accounts
  alias BibleReader.ReadingPlan
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

  test "stats_for_user returns rolling window fields", %{user: user, chapter: chapter} do
    assert {:ok, _} = ReadingPlan.log_chapter_read(user, chapter.id)
    user = Accounts.get_user!(user.id)
    stats = ReadingPlan.stats_for_user(user, rolling_days: 30)
    assert stats.rolling_days == 30
    assert stats.chapters_read_in_window >= 1
    assert stats.distinct_chapters_read_at_least_once >= 1
    assert stats.total_chapters_in_scope >= 1
  end
end

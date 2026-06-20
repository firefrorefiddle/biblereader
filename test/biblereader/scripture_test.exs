defmodule BibleReader.ScriptureTest do
  use BibleReader.DataCase, async: true

  import BibleReader.AccountsFixtures

  alias BibleReader.Scripture
  alias BibleReader.ScriptureFixtures

  setup do
    user = user_fixture()
    %{user: user}
  end

  test "list_books_for_user excludes apocrypha by default", %{user: user} do
    {:ok, _} =
      BibleReader.Accounts.update_user_reading_profile(user, %{show_apocrypha: false})

    user = BibleReader.Accounts.get_user!(user.id)
    books = Scripture.list_books_for_user(user)
    assert Enum.all?(books, & &1.in_protestant_canon)
  end

  test "list_chapters_grouped_by_book_for_user loads chapters in one query", %{user: user} do
    %{book: book, chapter: chapter} = ScriptureFixtures.book_and_chapter_fixture()

    grouped = Scripture.list_chapters_grouped_by_book_for_user(user)
    assert [chapter_row] = Map.get(grouped, book.id, [])
    assert chapter_row.id == chapter.id
  end

  describe "chapter navigation" do
    setup do
      %{book: book_a, chapters: [ch_a1, ch_a2]} =
        ScriptureFixtures.book_and_chapter_fixture(%{
          code: "NAV1",
          name: "Nav One",
          sort_order: 10,
          chapter_count: 2
        })

      %{book: book_b, chapters: [ch_b1]} =
        ScriptureFixtures.book_and_chapter_fixture(%{
          code: "NAV2",
          name: "Nav Two",
          sort_order: 11,
          chapter_count: 1
        })

      user = user_fixture()

      %{
        user: user,
        book_a: book_a,
        book_b: book_b,
        ch_a1: ch_a1,
        ch_a2: ch_a2,
        ch_b1: ch_b1
      }
    end

    test "next_chapter_for_user within book", %{
      user: user,
      book_a: book_a,
      ch_a1: ch_a1,
      ch_a2: ch_a2
    } do
      assert %{book: book, chapter: chapter} =
               Scripture.next_chapter_for_user(user, book_a, ch_a1)

      assert book.id == book_a.id
      assert chapter.id == ch_a2.id
    end

    test "next_chapter_for_user crosses to next book at last chapter", %{
      user: user,
      book_a: book_a,
      book_b: book_b,
      ch_a2: ch_a2,
      ch_b1: ch_b1
    } do
      assert %{book: book, chapter: chapter} =
               Scripture.next_chapter_for_user(user, book_a, ch_a2)

      assert book.id == book_b.id
      assert chapter.id == ch_b1.id
    end

    test "next_chapter_for_user is nil at catalog end", %{
      user: user,
      book_b: book_b,
      ch_b1: ch_b1
    } do
      assert Scripture.next_chapter_for_user(user, book_b, ch_b1) == nil
    end

    test "previous_chapter_for_user within book", %{
      user: user,
      book_a: book_a,
      ch_a1: ch_a1,
      ch_a2: ch_a2
    } do
      assert %{book: book, chapter: chapter} =
               Scripture.previous_chapter_for_user(user, book_a, ch_a2)

      assert book.id == book_a.id
      assert chapter.id == ch_a1.id
    end

    test "previous_chapter_for_user crosses to previous book at chapter 1", %{
      user: user,
      book_a: book_a,
      book_b: book_b,
      ch_a2: ch_a2,
      ch_b1: ch_b1
    } do
      assert %{book: book, chapter: chapter} =
               Scripture.previous_chapter_for_user(user, book_b, ch_b1)

      assert book.id == book_a.id
      assert chapter.id == ch_a2.id
    end

    test "previous_chapter_for_user is nil at catalog start", %{
      user: user,
      book_a: book_a,
      ch_a1: ch_a1
    } do
      assert Scripture.previous_chapter_for_user(user, book_a, ch_a1) == nil
    end

    test "navigation respects apocrypha visibility", %{user: user} do
      %{book: book_a, chapters: [_ch_a1, ch_a2]} =
        ScriptureFixtures.book_and_chapter_fixture(%{
          code: "APNA",
          name: "Apoc Nav A",
          sort_order: 900,
          chapter_count: 2
        })

      %{book: apoc_book, chapters: [apoc_ch1]} =
        ScriptureFixtures.book_and_chapter_fixture(%{
          code: "APNB",
          name: "Apoc Nav B",
          sort_order: 901,
          in_protestant_canon: false,
          in_apocrypha: true,
          chapter_count: 1
        })

      {:ok, _} =
        BibleReader.Accounts.update_user_reading_profile(user, %{show_apocrypha: false})

      user = BibleReader.Accounts.get_user!(user.id)

      assert Scripture.next_chapter_for_user(user, book_a, ch_a2) == nil

      {:ok, _} =
        BibleReader.Accounts.update_user_reading_profile(user, %{show_apocrypha: true})

      user = BibleReader.Accounts.get_user!(user.id)

      assert %{book: book, chapter: chapter} =
               Scripture.next_chapter_for_user(user, book_a, ch_a2)

      assert book.id == apoc_book.id
      assert chapter.id == apoc_ch1.id
    end
  end
end

defmodule BibleReader.ScriptureTest do
  use BibleReader.DataCase, async: true

  import BibleReader.AccountsFixtures

  alias BibleReader.Scripture
  alias BibleReader.ScriptureFixtures

  setup do
    ScriptureFixtures.book_and_chapter_fixture(%{code: "GEN", name: "Genesis"})
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
end

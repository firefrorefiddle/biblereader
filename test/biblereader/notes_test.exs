defmodule BibleReader.NotesTest do
  use BibleReader.DataCase, async: true

  import BibleReader.AccountsFixtures

  alias BibleReader.Notes
  alias BibleReader.ScriptureFixtures

  setup do
    %{chapter: chapter} = ScriptureFixtures.book_and_chapter_fixture()
    user = user_fixture()
    %{user: user, chapter: chapter}
  end

  test "upsert_note inserts then updates", %{user: user, chapter: chapter} do
    assert {:ok, note} = Notes.upsert_note(user, chapter.id, "First thought")
    assert note.body == "First thought"

    assert {:ok, updated} = Notes.upsert_note(user, chapter.id, "Updated")
    assert updated.id == note.id
    assert updated.body == "Updated"
    assert Notes.get_note(user.id, chapter.id).body == "Updated"
  end

  test "count_notes_for_user", %{user: user, chapter: chapter} do
    assert Notes.count_notes_for_user(user.id) == 0
    assert {:ok, _} = Notes.upsert_note(user, chapter.id, "note")
    assert Notes.count_notes_for_user(user.id) == 1
  end

  test "chapter_ids_with_notes", %{user: user, chapter: chapter} do
    assert MapSet.new() == Notes.chapter_ids_with_notes(user.id)
    assert {:ok, _} = Notes.upsert_note(user, chapter.id, "x")
    assert MapSet.member?(Notes.chapter_ids_with_notes(user.id), chapter.id)
  end
end

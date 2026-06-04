defmodule BibleReader.Notes do
  @moduledoc """
  Per-chapter notes for authenticated users (one note row per user/chapter).
  """

  import Ecto.Query

  alias BibleReader.Accounts.User
  alias BibleReader.Notes.ChapterNote
  alias BibleReader.Repo

  @doc """
  Returns the note for `user_id` and `chapter_id`, or `nil`.
  """
  def get_note(user_id, chapter_id) when is_integer(user_id) and is_integer(chapter_id) do
    Repo.get_by(ChapterNote, user_id: user_id, chapter_id: chapter_id)
  end

  @doc """
  Inserts or updates the note body for this user/chapter.
  """
  def upsert_note(%User{id: user_id}, chapter_id, body)
      when is_integer(chapter_id) and is_binary(body) do
    case get_note(user_id, chapter_id) do
      nil ->
        %ChapterNote{}
        |> ChapterNote.changeset(%{user_id: user_id, chapter_id: chapter_id, body: body})
        |> Repo.insert()

      %ChapterNote{} = note ->
        note
        |> ChapterNote.changeset(%{body: body})
        |> Repo.update()
    end
  end

  @doc """
  Total number of chapter notes for this user (non-empty body optional—counts all rows).
  """
  def count_notes_for_user(user_id) when is_integer(user_id) do
    from(n in ChapterNote, where: n.user_id == ^user_id, select: count(n.id))
    |> Repo.one()
  end

  @doc """
  Set of `chapter_id` values that have a note for this user (any body, including empty).
  """
  def chapter_ids_with_notes(user_id) when is_integer(user_id) do
    from(n in ChapterNote, where: n.user_id == ^user_id, select: n.chapter_id)
    |> Repo.all()
    |> MapSet.new()
  end
end

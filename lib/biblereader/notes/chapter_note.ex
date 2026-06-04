defmodule BibleReader.Notes.ChapterNote do
  use Ecto.Schema
  import Ecto.Changeset

  schema "chapter_notes" do
    field :body, :string
    belongs_to :user, BibleReader.Accounts.User
    belongs_to :chapter, BibleReader.Scripture.Chapter

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(note, attrs) do
    note
    |> cast(attrs, [:body, :user_id, :chapter_id])
    |> validate_required([:user_id, :chapter_id])
    |> validate_length(:body, max: 50_000)
    |> foreign_key_constraint(:user_id)
    |> foreign_key_constraint(:chapter_id)
    |> unique_constraint([:user_id, :chapter_id])
  end
end

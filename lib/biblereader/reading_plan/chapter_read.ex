defmodule BibleReader.ReadingPlan.ChapterRead do
  use Ecto.Schema
  import Ecto.Changeset

  schema "chapter_reads" do
    field :read_at, :utc_datetime
    belongs_to :user, BibleReader.Accounts.User
    belongs_to :chapter, BibleReader.Scripture.Chapter
  end

  @doc false
  def changeset(read, attrs) do
    read
    |> cast(attrs, [:read_at, :user_id, :chapter_id])
    |> validate_required([:read_at, :user_id, :chapter_id])
    |> foreign_key_constraint(:user_id)
    |> foreign_key_constraint(:chapter_id)
  end
end

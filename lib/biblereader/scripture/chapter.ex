defmodule BibleReader.Scripture.Chapter do
  use Ecto.Schema
  import Ecto.Changeset

  schema "chapters" do
    field :chapter_number, :integer
    belongs_to :book, BibleReader.Scripture.Book

    has_many :chapter_reads, BibleReader.ReadingPlan.ChapterRead
  end

  @doc false
  def changeset(chapter, attrs) do
    chapter
    |> cast(attrs, [:chapter_number, :book_id])
    |> validate_required([:chapter_number, :book_id])
    |> foreign_key_constraint(:book_id)
    |> unique_constraint([:book_id, :chapter_number])
  end
end

defmodule BibleReader.ScriptureText.ChapterDocument do
  use Ecto.Schema
  import Ecto.Changeset

  schema "chapter_documents" do
    field :blocks_json, {:array, :map}, default: []

    belongs_to :translation, BibleReader.ScriptureText.Translation
    belongs_to :chapter, BibleReader.Scripture.Chapter

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(chapter_document, attrs) do
    chapter_document
    |> cast(attrs, [:translation_id, :chapter_id, :blocks_json])
    |> validate_required([:translation_id, :chapter_id, :blocks_json])
    |> foreign_key_constraint(:translation_id)
    |> foreign_key_constraint(:chapter_id)
    |> unique_constraint([:translation_id, :chapter_id])
  end
end

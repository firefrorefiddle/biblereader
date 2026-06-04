defmodule BibleReader.ScriptureText.Verse do
  use Ecto.Schema
  import Ecto.Changeset

  schema "bible_verses" do
    field :verse_number, :integer
    field :plain_text, :string
    field :content_json, {:array, :map}, default: []

    belongs_to :translation, BibleReader.ScriptureText.Translation
    belongs_to :chapter, BibleReader.Scripture.Chapter

    has_many :footnotes, BibleReader.ScriptureText.Footnote

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(verse, attrs) do
    verse
    |> cast(attrs, [:translation_id, :chapter_id, :verse_number, :plain_text, :content_json])
    |> validate_required([
      :translation_id,
      :chapter_id,
      :verse_number,
      :content_json
    ])
    |> foreign_key_constraint(:translation_id)
    |> foreign_key_constraint(:chapter_id)
    |> unique_constraint([:translation_id, :chapter_id, :verse_number])
  end
end

defmodule BibleReader.ScriptureText.Translation do
  use Ecto.Schema
  import Ecto.Changeset

  schema "bible_translations" do
    field :code, :string
    field :name, :string
    field :language, :string
    field :source_format, :string
    field :license, :string
    field :copyright_notice, :string
    field :source_path, :string

    has_many :chapter_documents, BibleReader.ScriptureText.ChapterDocument
    has_many :bible_verses, BibleReader.ScriptureText.Verse

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(translation, attrs) do
    translation
    |> cast(attrs, [
      :code,
      :name,
      :language,
      :source_format,
      :license,
      :copyright_notice,
      :source_path
    ])
    |> validate_required([:code, :name, :language, :source_format])
    |> unique_constraint(:code)
  end
end

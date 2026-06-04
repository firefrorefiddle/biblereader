defmodule BibleReader.ScriptureText.Footnote do
  use Ecto.Schema
  import Ecto.Changeset

  schema "bible_footnotes" do
    field :marker, :string
    field :ref_id, :string
    field :body, :string
    field :position, :integer
    field :display_number, :integer

    belongs_to :verse, BibleReader.ScriptureText.Verse

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(footnote, attrs) do
    footnote
    |> cast(attrs, [:verse_id, :marker, :ref_id, :body, :position, :display_number])
    |> validate_required([:verse_id, :marker, :ref_id, :body, :position, :display_number])
    |> foreign_key_constraint(:verse_id)
  end
end

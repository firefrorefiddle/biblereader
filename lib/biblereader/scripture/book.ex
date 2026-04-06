defmodule BibleReader.Scripture.Book do
  use Ecto.Schema
  import Ecto.Changeset

  schema "books" do
    field :code, :string
    field :name, :string
    field :sort_order, :integer
    field :testament, :string
    field :in_protestant_canon, :boolean, default: false
    field :in_apocrypha, :boolean, default: false

    has_many :chapters, BibleReader.Scripture.Chapter
  end

  @doc false
  def changeset(book, attrs) do
    book
    |> cast(attrs, [
      :code,
      :name,
      :sort_order,
      :testament,
      :in_protestant_canon,
      :in_apocrypha
    ])
    |> validate_required([:code, :name, :sort_order, :testament])
    |> unique_constraint(:code)
  end
end

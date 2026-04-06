defmodule BibleReader.Scripture.Seed do
  @moduledoc """
  Idempotent seed of books and chapters from `Catalog`. Safe to run multiple times.
  """

  import Ecto.Query, only: [from: 2]

  alias BibleReader.Repo
  alias BibleReader.Scripture.{Book, Chapter, Catalog}

  @doc """
  Inserts catalog rows when the `books` table is empty.
  """
  def run do
    if Repo.one(from(b in Book, select: count(b.id))) > 0 do
      :skipped
    else
      Catalog.books()
      |> Enum.with_index(1)
      |> Enum.each(fn {book, sort_order} ->
        {:ok, b} =
          %Book{}
          |> Book.changeset(%{
            code: book.code,
            name: book.name,
            sort_order: sort_order,
            testament: Atom.to_string(book.testament),
            in_protestant_canon: book.in_protestant_canon,
            in_apocrypha: book.in_apocrypha
          })
          |> Repo.insert()

        Enum.each(1..book.chapter_count, fn n ->
          %Chapter{}
          |> Chapter.changeset(%{book_id: b.id, chapter_number: n})
          |> Repo.insert!()
        end)
      end)

      :ok
    end
  end
end

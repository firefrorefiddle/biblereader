defmodule BibleReader.ScriptureFixtures do
  @moduledoc false

  alias BibleReader.Repo
  alias BibleReader.Scripture.{Book, Chapter}

  @doc """
  Inserts a minimal book and one chapter for tests.
  """
  def book_and_chapter_fixture(attrs \\ %{}) do
    chapter_count = Map.get(attrs, :chapter_count, 1)
    attrs = Map.drop(attrs, [:chapter_count])

    {:ok, book} =
      %Book{}
      |> Book.changeset(
        Map.merge(
          %{
            code: "TST",
            name: "Test Book",
            sort_order: 1,
            testament: "ot",
            in_protestant_canon: true,
            in_apocrypha: false
          },
          attrs
        )
      )
      |> Repo.insert()

    chapters =
      for n <- 1..chapter_count do
        {:ok, chapter} =
          %Chapter{}
          |> Chapter.changeset(%{book_id: book.id, chapter_number: n})
          |> Repo.insert()

        chapter
      end

    %{book: book, chapter: hd(chapters), chapters: chapters}
  end
end

defmodule BibleReader.ScriptureFixtures do
  @moduledoc false

  alias BibleReader.Repo
  alias BibleReader.Scripture.{Book, Chapter}

  @doc """
  Inserts a minimal book and one chapter for tests.
  """
  def book_and_chapter_fixture(attrs \\ %{}) do
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

    {:ok, chapter} =
      %Chapter{}
      |> Chapter.changeset(%{book_id: book.id, chapter_number: 1})
      |> Repo.insert()

    %{book: book, chapter: chapter}
  end
end

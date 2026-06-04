defmodule BibleReader.Scripture do
  @moduledoc """
  Read-only access to the **Scripture** catalog: books and chapters (no verse text).
  """

  import Ecto.Query

  alias BibleReader.Repo
  alias BibleReader.Scripture.{Book, Chapter}

  @doc """
  Books visible to this user: Protestant canon always; apocrypha/deuterocanon only if
  `user.show_apocrypha` is true.
  """
  def list_books_for_user(%BibleReader.Accounts.User{} = user) do
    q =
      from b in Book,
        where:
          b.in_protestant_canon == true or
            (b.in_apocrypha == true and ^user.show_apocrypha == true),
        order_by: [asc: b.sort_order]

    Repo.all(q)
  end

  @doc """
  Returns a book by stable `code`, or `nil`.
  """
  def get_book_by_code(book_code) when is_binary(book_code) do
    Repo.get_by(Book, code: book_code)
  end

  @doc """
  Returns the book if visible to this user (canon/apocrypha rules), else `nil`.
  """
  def get_book_for_user(%BibleReader.Accounts.User{} = user, book_code)
      when is_binary(book_code) do
    case get_book_by_code(book_code) do
      %Book{in_protestant_canon: true} = book ->
        book

      %Book{in_apocrypha: true} = book ->
        if user.show_apocrypha, do: book, else: nil

      nil ->
        nil
    end
  end

  @doc """
  All chapters for a book (by id), ordered by chapter number.
  """
  def list_chapters_for_book(book_id) do
    from(c in Chapter,
      where: c.book_id == ^book_id,
      order_by: [asc: c.chapter_number]
    )
    |> Repo.all()
  end

  @doc """
  Returns the chapter row for a book code and chapter number, or `nil`.
  """
  def get_chapter_by_code_and_number(book_code, chapter_number)
      when is_binary(book_code) and is_integer(chapter_number) do
    from(c in Chapter,
      join: b in assoc(c, :book),
      where: b.code == ^book_code and c.chapter_number == ^chapter_number,
      select: c,
      preload: [:book]
    )
    |> Repo.one()
  end
end

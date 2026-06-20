defmodule BibleReader.Scripture do
  @moduledoc """
  Read-only access to the **Scripture** catalog: books and chapters (no verse text).
  """

  import Ecto.Query

  alias BibleReader.Repo
  alias BibleReader.Scripture.{Book, BookNames, Chapter}

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
  All chapters visible to this user, grouped by `book_id`.

  Single query for bible overview and other bulk chapter views.
  """
  def list_chapters_grouped_by_book_for_user(%BibleReader.Accounts.User{} = user) do
    from(c in Chapter,
      join: b in Book,
      on: c.book_id == b.id,
      where:
        b.in_protestant_canon == true or
          (b.in_apocrypha == true and ^user.show_apocrypha == true),
      order_by: [asc: b.sort_order, asc: c.chapter_number]
    )
    |> Repo.all()
    |> Enum.group_by(& &1.book_id)
  end

  @doc """
  Localized book title for UI (OSIS `code` + user locale).
  """
  def book_display_name(book, locale) when is_binary(locale) do
    BookNames.display_name(book, locale)
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

  @doc """
  Returns the previous chapter visible to this user, or `nil` at the start of the catalog.

  Same book uses `chapter_number - 1`; at chapter 1, uses the last chapter of the prior
  book in `list_books_for_user/1` order (respecting apocrypha preference).
  """
  def previous_chapter_for_user(%BibleReader.Accounts.User{} = user, %Book{} = book, %Chapter{
        chapter_number: n
      }) do
    if n > 1 do
      chapter_ref(user, book, n - 1)
    else
      previous_book_last_chapter(user, book)
    end
  end

  @doc """
  Returns the next chapter visible to this user, or `nil` at the end of the catalog.

  Same book uses `chapter_number + 1`; at the book's last chapter, uses chapter 1 of the
  next visible book (respecting apocrypha preference).
  """
  def next_chapter_for_user(%BibleReader.Accounts.User{} = user, %Book{} = book, %Chapter{
        chapter_number: n
      }) do
    max = max_chapter_number(book.id)

    if n < max do
      chapter_ref(user, book, n + 1)
    else
      next_book_first_chapter(user, book)
    end
  end

  defp chapter_ref(_user, %Book{code: code} = book, chapter_number) do
    case get_chapter_by_code_and_number(code, chapter_number) do
      %Chapter{} = chapter -> %{book: book, chapter: chapter}
      nil -> nil
    end
  end

  defp previous_book_last_chapter(user, %Book{} = current) do
    books = list_books_for_user(user)

    case Enum.split_while(books, &(&1.id != current.id)) do
      {prev_books, [_current | _]} ->
        case List.last(prev_books) do
          %Book{id: book_id, code: code} = book ->
            case last_chapter_number(book_id) do
              n when is_integer(n) and n > 0 ->
                case get_chapter_by_code_and_number(code, n) do
                  %Chapter{} = chapter -> %{book: book, chapter: chapter}
                  nil -> nil
                end

              _ ->
                nil
            end

          nil ->
            nil
        end

      _ ->
        nil
    end
  end

  defp next_book_first_chapter(user, %Book{} = current) do
    books = list_books_for_user(user)

    case Enum.drop_while(books, &(&1.id != current.id)) do
      [_current | rest] ->
        case rest do
          [%Book{code: code} = book | _] ->
            case get_chapter_by_code_and_number(code, 1) do
              %Chapter{} = chapter -> %{book: book, chapter: chapter}
              nil -> nil
            end

          [] ->
            nil
        end

      _ ->
        nil
    end
  end

  defp max_chapter_number(book_id) do
    from(c in Chapter,
      where: c.book_id == ^book_id,
      select: max(c.chapter_number)
    )
    |> Repo.one()
    |> Kernel.||(0)
  end

  defp last_chapter_number(book_id) do
    max_chapter_number(book_id)
  end
end

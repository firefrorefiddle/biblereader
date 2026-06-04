defmodule BibleReader.Scripture.BookNames do
  @moduledoc """
  Localized Bible book display names (Gettext domain `books`, msgid = OSIS code).
  """
  alias BibleReader.Scripture.Book
  alias BibleReader.Scripture.Catalog

  @english_names Catalog.books() |> Map.new(fn b -> {b.code, b.name} end)

  @doc """
  Returns the display name for a book code or `%Book{}` in the given locale.
  Falls back to the English catalog name when no translation exists.
  """
  @spec display_name(Book.t() | String.t(), String.t()) :: String.t()
  def display_name(%Book{code: code, name: name}, locale), do: display_name(code, locale, name)

  def display_name(code, locale) when is_binary(code) do
    display_name(code, locale, Map.get(@english_names, code, code))
  end

  defp display_name(code, locale, fallback) do
    Gettext.with_locale(BibleReaderWeb.Gettext, locale, fn ->
      translated = Gettext.dgettext(BibleReaderWeb.Gettext, "books", code)
      if translated == code, do: fallback, else: translated
    end)
  end
end

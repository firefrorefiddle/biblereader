defmodule BibleReaderWeb.ChapterGrid do
  @moduledoc """
  Builds chapter grid cell maps shared by book and bible overview LiveViews.
  """

  use BibleReaderWeb, :verified_routes

  alias BibleReader.ReadingPlan
  alias BibleReaderWeb.RelativeTimeFormat

  @doc """
  Returns a list of chapter cell maps for `chapter_cell/1`.
  """
  def build_cells(chapters, book, counts, last_at, note_ids, timezone, locale) do
    Enum.map(chapters, fn ch ->
      read_count = Map.get(counts, ch.id, 0)
      last = Map.get(last_at, ch.id)
      bucket = ReadingPlan.age_bucket(read_count, last, timezone)

      age_label =
        if read_count > 0 do
          last
          |> ReadingPlan.relative_label(timezone)
          |> RelativeTimeFormat.format(locale)
        end

      %{
        number: ch.chapter_number,
        chapter_id: ch.id,
        read_count: read_count,
        age_label: age_label,
        bucket: bucket,
        has_note?: MapSet.member?(note_ids, ch.id),
        to: ~p"/read/books/#{book.code}/#{ch.chapter_number}"
      }
    end)
  end

  @doc false
  def chapter_id_set(cells) when is_list(cells) do
    cells
    |> Enum.map(& &1.chapter_id)
    |> MapSet.new()
  end

  @doc false
  def valid_chapter_id?(cells, chapter_id) when is_list(cells) and is_integer(chapter_id) do
    Enum.any?(cells, &(&1.chapter_id == chapter_id))
  end
end

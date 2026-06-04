defmodule BibleReaderWeb.BookLive do
  @moduledoc """
  Single-book chapter grid with read-age styling and navigation to chapter view.
  """
  use BibleReaderWeb, :live_view

  alias BibleReader.Accounts
  alias BibleReader.Notes
  alias BibleReader.ReadingPlan
  alias BibleReader.Scripture

  @impl true
  def render(assigns) do
    ~H"""
    <div class="reading-record mx-auto max-w-4xl px-1 py-6 sm:px-2">
      <nav class="mb-4 text-sm">
        <.link navigate={~p"/read"} class="text-primary hover:underline">← Books</.link>
      </nav>

      <header class="mb-6 border-b border-zinc-200 pb-4">
        <h1 class="font-serif text-2xl font-semibold text-zinc-900">{@book.name}</h1>
        <p class="mt-1 text-sm text-zinc-600">
          {@chapters_read} of {@total_chapters} chapters read
        </p>
        <p :if={@last_chapter_number} class="mt-1 text-sm text-zinc-600">
          Last read: chapter {@last_chapter_number}
          <span :if={@last_read_label}>· {@last_read_label}</span>
        </p>
      </header>

      <div :if={@continue_chapter} class="mb-8">
        <.link
          navigate={~p"/read/books/#{@book.code}/#{@continue_chapter.chapter_number}"}
          class="inline-flex rounded-lg bg-primary px-4 py-2.5 text-sm font-medium text-white hover:bg-primary/90"
        >
          Continue {@book.name} {@continue_chapter.chapter_number}
        </.link>
      </div>

      <section>
        <h2 class="mb-3 text-sm font-semibold uppercase tracking-wide text-zinc-500">Chapters</h2>
        <div class="inline-grid max-w-full gap-px rounded-sm border border-zinc-300 bg-white p-px [grid-template-columns:repeat(auto-fill,minmax(2rem,2.75rem))]">
          <%= for ch <- @chapter_cells do %>
            <.chapter_cell
              number={ch.number}
              read_count={ch.read_count}
              age_label={ch.age_label}
              bucket={ch.bucket}
              has_note?={ch.has_note?}
              to={ch.to}
              book_name={@book.name}
            />
          <% end %>
        </div>
        <.chapter_grid_legend />
      </section>
    </div>
    """
  end

  @impl true
  def mount(%{"book_code" => book_code}, _session, socket) do
    user = Accounts.get_user!(socket.assigns.current_user.id)

    case Scripture.get_book_for_user(user, book_code) do
      nil ->
        {:ok,
         socket
         |> put_flash(:error, "Book not found.")
         |> push_navigate(to: ~p"/read")}

      book ->
        {:ok, load_book(socket, user, book)}
    end
  end

  defp load_book(socket, user, book) do
    timezone = user.timezone || "Etc/UTC"
    counts = ReadingPlan.read_counts_by_chapter_id(user.id)
    last_at = ReadingPlan.last_read_at_by_chapter_id(user.id)
    note_ids = Notes.chapter_ids_with_notes(user.id)

    chapters = Scripture.list_chapters_for_book(book.id)

    chapter_cells =
      Enum.map(chapters, fn ch ->
        read_count = Map.get(counts, ch.id, 0)
        last = Map.get(last_at, ch.id)
        bucket = ReadingPlan.age_bucket(read_count, last, timezone)

        age_label =
          if read_count > 0, do: ReadingPlan.relative_label(last, timezone), else: nil

        %{
          number: ch.chapter_number,
          read_count: read_count,
          age_label: age_label,
          bucket: bucket,
          has_note?: MapSet.member?(note_ids, ch.id),
          to: ~p"/read/books/#{book.code}/#{ch.chapter_number}"
        }
      end)

    chapters_read = Enum.count(chapters, fn ch -> Map.get(counts, ch.id, 0) > 0 end)
    total = length(chapters)

    {last_chapter_number, last_read_label} =
      chapters
      |> Enum.filter(fn ch -> Map.has_key?(last_at, ch.id) end)
      |> Enum.map(fn ch -> {ch.chapter_number, Map.get(last_at, ch.id)} end)
      |> Enum.max_by(fn {_n, at} -> at end, fn -> {nil, nil} end)
      |> then(fn
        {n, at} when not is_nil(at) ->
          {n, ReadingPlan.relative_label(at, timezone)}

        _ ->
          {nil, nil}
      end)

    continue_chapter = continue_in_book(user, book, chapters, last_at)

    socket
    |> assign(:page_title, book.name)
    |> assign(:book, book)
    |> assign(:chapter_cells, chapter_cells)
    |> assign(:chapters_read, chapters_read)
    |> assign(:total_chapters, total)
    |> assign(:last_chapter_number, last_chapter_number)
    |> assign(:last_read_label, last_read_label)
    |> assign(:continue_chapter, continue_chapter)
  end

  defp continue_in_book(_user, _book, chapters, last_at) do
    last_ch =
      chapters
      |> Enum.filter(fn ch -> Map.has_key?(last_at, ch.id) end)
      |> Enum.max_by(fn ch -> Map.get(last_at, ch.id) end, fn -> nil end)

    cond do
      is_nil(last_ch) ->
        Enum.find(chapters, &(&1.chapter_number == 1))

      true ->
        Enum.find(chapters, &(&1.chapter_number == last_ch.chapter_number + 1))
    end
  end
end

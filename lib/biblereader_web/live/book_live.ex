defmodule BibleReaderWeb.BookLive do
  @moduledoc """
  Single-book chapter grid with read-age styling and navigation to chapter view.
  """
  use BibleReaderWeb, :live_view

  alias BibleReader.Accounts
  alias BibleReader.Notes
  alias BibleReader.ReadingPlan
  alias BibleReader.Scripture
  alias BibleReaderWeb.RelativeTimeFormat
  alias BibleReaderWeb.EffectiveDate, as: EffectiveDateUI

  @impl true
  def render(assigns) do
    ~H"""
    <div class="reading-record mx-auto max-w-4xl px-1 py-6 sm:px-2">
      <nav class="mb-4 text-sm">
        <.link navigate={~p"/read"} class="text-primary hover:underline">
          ← {gettext("Books")}
        </.link>
      </nav>

      <header class="mb-6 border-b border-zinc-200 pb-4">
        <h1 class="font-serif text-2xl font-semibold text-zinc-900">{@book_name}</h1>
        <p class="mt-1 text-sm text-zinc-600">
          {gettext("%{read} of %{total} chapters read",
            read: @chapters_read,
            total: @total_chapters
          )}
        </p>
        <p :if={@last_chapter_number} class="mt-1 text-sm text-zinc-600">
          {gettext("Last read: chapter %{number}", number: @last_chapter_number)}
          <span :if={@last_read_label}>· {@last_read_label}</span>
        </p>
      </header>

      <div :if={@continue_chapter} class="mb-8">
        <.link
          navigate={~p"/read/books/#{@book.code}/#{@continue_chapter.chapter_number}"}
          class="inline-flex rounded-lg bg-primary px-4 py-2.5 text-sm font-medium text-white hover:bg-primary/90"
        >
          {gettext("Continue %{book} %{chapter}",
            book: @book_name,
            chapter: @continue_chapter.chapter_number
          )}
        </.link>
      </div>

      <section>
        <h2 class="mb-3 text-sm font-semibold uppercase tracking-wide text-zinc-500">
          {gettext("Chapters")}
        </h2>
        <div class="inline-grid max-w-full gap-px rounded-sm border border-zinc-300 bg-white p-px [grid-template-columns:repeat(auto-fill,minmax(2rem,2.75rem))]">
          <%= for ch <- @chapter_cells do %>
            <.chapter_cell
              number={ch.number}
              chapter_id={ch.chapter_id}
              read_count={ch.read_count}
              age_label={ch.age_label}
              bucket={ch.bucket}
              has_note?={ch.has_note?}
              to={ch.to}
              book_name={@book_name}
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
         |> put_flash(:error, gettext("Book not found."))
         |> push_navigate(to: ~p"/read")}

      book ->
        {:ok, load_book(socket, user, book)}
    end
  end

  @impl true
  def handle_event("open_effective_date_picker", _params, socket) do
    {:noreply, EffectiveDateUI.open_picker(socket)}
  end

  def handle_event("close_effective_date_picker", _params, socket) do
    {:noreply, EffectiveDateUI.close_picker(socket)}
  end

  def handle_event("log_read", %{"chapter-id" => chapter_id_str}, socket) do
    user = Accounts.get_user!(socket.assigns.current_user.id)

    with {chapter_id, ""} <- Integer.parse(chapter_id_str),
         true <- Enum.any?(socket.assigns.chapter_cells, &(&1.chapter_id == chapter_id)) do
      read_at = EffectiveDateUI.read_at_for_logging(user, socket.assigns.effective_date)

      case ReadingPlan.log_chapter_read(user, chapter_id, read_at) do
        {:ok, _} ->
          {:noreply,
           socket
           |> put_flash(:chapter_read, Integer.to_string(chapter_id))
           |> load_book(Accounts.get_user!(user.id), socket.assigns.book)}

        {:error, _} ->
          {:noreply, put_flash(socket, :error, gettext("Could not log read."))}
      end
    else
      _ ->
        {:noreply, put_flash(socket, :error, gettext("Could not log read."))}
    end
  end

  def handle_event("undo_read", %{"chapter-id" => chapter_id_str}, socket) do
    user = Accounts.get_user!(socket.assigns.current_user.id)

    with {chapter_id, ""} <- Integer.parse(chapter_id_str),
         true <- Enum.any?(socket.assigns.chapter_cells, &(&1.chapter_id == chapter_id)),
         {:ok, _} <- ReadingPlan.undo_last_chapter_read(user, chapter_id) do
      {:noreply,
       socket
       |> clear_flash(:chapter_read)
       |> load_book(Accounts.get_user!(user.id), socket.assigns.book)}
    else
      _ ->
        {:noreply, put_flash(socket, :error, gettext("Could not undo read."))}
    end
  end

  defp load_book(socket, user, book) do
    locale = socket.assigns.locale
    book_name = Scripture.book_display_name(book, locale)
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
          if read_count > 0,
            do:
              last
              |> ReadingPlan.relative_label(timezone)
              |> RelativeTimeFormat.format(locale),
            else: nil

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

    chapters_read = Enum.count(chapters, fn ch -> Map.get(counts, ch.id, 0) > 0 end)
    total = length(chapters)

    {last_chapter_number, last_read_label} =
      chapters
      |> Enum.filter(fn ch -> Map.has_key?(last_at, ch.id) end)
      |> Enum.map(fn ch -> {ch.chapter_number, Map.get(last_at, ch.id)} end)
      |> Enum.max_by(fn {_n, at} -> at end, fn -> {nil, nil} end)
      |> then(fn
        {n, at} when not is_nil(at) ->
          label =
            at
            |> ReadingPlan.relative_label(timezone)
            |> RelativeTimeFormat.format(locale)

          {n, label}

        _ ->
          {nil, nil}
      end)

    continue_chapter = continue_in_book(user, book, chapters, last_at)

    socket
    |> assign(:page_title, book_name)
    |> assign(:locale_return_to, ~p"/read/books/#{book.code}")
    |> assign(:book, book)
    |> assign(:book_name, book_name)
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

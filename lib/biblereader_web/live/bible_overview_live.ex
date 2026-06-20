defmodule BibleReaderWeb.BibleOverviewLive do
  @moduledoc """
  Full-bible chapter grid: every visible book with collapsible chapter rows and mark-as-read.
  """
  use BibleReaderWeb, :live_view

  alias BibleReader.Accounts
  alias BibleReader.Notes
  alias BibleReader.ReadingPlan
  alias BibleReaderWeb.ChapterGrid
  alias BibleReaderWeb.EffectiveDate, as: EffectiveDateUI

  @impl true
  def render(assigns) do
    ~H"""
    <div class="reading-bible-overview mx-auto max-w-4xl px-1 py-6 sm:px-2">
      <nav class="mb-4 text-sm">
        <.link navigate={~p"/read"} class="text-primary hover:underline">
          ← {gettext("Books")}
        </.link>
      </nav>

      <header class="mb-6 border-b border-zinc-200 pb-4">
        <h1 class="font-serif text-2xl font-semibold text-zinc-900">
          {gettext("Bible overview")}
        </h1>
        <p class="mt-1 text-sm text-zinc-600">
          {gettext("%{read} of %{total} chapters read",
            read: @summary.chapters_read,
            total: @summary.total_chapters
          )}
        </p>
      </header>

      <div class="mb-4 flex flex-wrap items-center gap-2">
        <button
          :for={{filter, label} <- testament_filters()}
          type="button"
          phx-click="filter_testament"
          phx-value-filter={filter}
          class={[
            "rounded-full px-3 py-1.5 text-sm font-medium transition",
            if(@testament_filter == filter,
              do: "bg-primary text-white",
              else: "bg-zinc-100 text-zinc-700 hover:bg-zinc-200"
            )
          ]}
        >
          {label}
        </button>
        <span class="mx-1 hidden h-4 w-px bg-zinc-200 sm:inline" />
        <button
          type="button"
          phx-click="expand_all"
          class="rounded-full px-3 py-1.5 text-sm font-medium text-primary hover:bg-primary-muted"
        >
          {gettext("Expand all")}
        </button>
        <button
          type="button"
          phx-click="collapse_all"
          class="rounded-full px-3 py-1.5 text-sm font-medium text-zinc-700 hover:bg-zinc-100"
        >
          {gettext("Collapse all")}
        </button>
      </div>

      <div class="space-y-3">
        <%= for section <- filtered_sections(@book_sections, @testament_filter) do %>
          <.book_overview_section
            book_name={section.book_name}
            book_code={section.book.code}
            chapters_read={section.chapters_read}
            total_chapters={section.total_chapters}
            chapter_cells={section.chapter_cells}
            expanded?={MapSet.member?(@expanded_books, section.book.code)}
          />
        <% end %>
      </div>

      <.chapter_grid_legend />
    </div>
    """
  end

  @impl true
  def mount(_params, _session, socket) do
    {:ok, load_overview(socket)}
  end

  @impl true
  def handle_event("open_effective_date_picker", _params, socket) do
    {:noreply, EffectiveDateUI.open_picker(socket)}
  end

  def handle_event("close_effective_date_picker", _params, socket) do
    {:noreply, EffectiveDateUI.close_picker(socket)}
  end

  def handle_event("filter_testament", %{"filter" => filter}, socket) do
    filter = String.to_existing_atom(filter)
    {:noreply, assign(socket, :testament_filter, filter)}
  end

  def handle_event("toggle_book", %{"code" => code}, socket) do
    expanded =
      if MapSet.member?(socket.assigns.expanded_books, code) do
        MapSet.delete(socket.assigns.expanded_books, code)
      else
        MapSet.put(socket.assigns.expanded_books, code)
      end

    {:noreply, assign(socket, :expanded_books, expanded)}
  end

  def handle_event("expand_all", _params, socket) do
    codes =
      socket.assigns.book_sections
      |> filtered_sections(socket.assigns.testament_filter)
      |> Enum.map(& &1.book.code)
      |> MapSet.new()

    {:noreply, assign(socket, :expanded_books, codes)}
  end

  def handle_event("collapse_all", _params, socket) do
    {:noreply, assign(socket, :expanded_books, MapSet.new())}
  end

  def handle_event("log_read", %{"chapter-id" => chapter_id_str}, socket) do
    user = Accounts.get_user!(socket.assigns.current_user.id)

    with {chapter_id, ""} <- Integer.parse(chapter_id_str),
         true <- MapSet.member?(socket.assigns.chapter_ids, chapter_id) do
      read_at = EffectiveDateUI.read_at_for_logging(user, socket.assigns.effective_date)

      case ReadingPlan.log_chapter_read(user, chapter_id, read_at) do
        {:ok, _} ->
          {:noreply,
           socket
           |> put_flash(:chapter_read, Integer.to_string(chapter_id))
           |> load_overview()}

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
         true <- MapSet.member?(socket.assigns.chapter_ids, chapter_id),
         {:ok, _} <- ReadingPlan.undo_last_chapter_read(user, chapter_id) do
      {:noreply,
       socket
       |> clear_flash(:chapter_read)
       |> load_overview()}
    else
      _ ->
        {:noreply, put_flash(socket, :error, gettext("Could not undo read."))}
    end
  end

  defp load_overview(socket) do
    user = Accounts.get_user!(socket.assigns.current_user.id)
    locale = socket.assigns.locale
    timezone = user.timezone || "Etc/UTC"
    note_ids = Notes.chapter_ids_with_notes(user.id)

    overview = ReadingPlan.bible_overview_for_user(user)
    counts = overview.counts
    last_at = overview.last_at

    book_sections =
      Enum.map(overview.sections, fn section ->
        chapter_cells =
          ChapterGrid.build_cells(
            section.chapters,
            section.book,
            counts,
            last_at,
            note_ids,
            timezone,
            locale
          )

        Map.merge(section, %{
          book_name: BibleReader.Scripture.book_display_name(section.book, locale),
          chapter_cells: chapter_cells
        })
      end)

    chapter_ids =
      book_sections
      |> Enum.flat_map(& &1.chapter_cells)
      |> ChapterGrid.chapter_id_set()

    expanded_books = Map.get(socket.assigns, :expanded_books, MapSet.new())

    socket
    |> assign(:page_title, gettext("Bible overview"))
    |> assign(:locale_return_to, ~p"/read/bible")
    |> assign(:summary, %{
      chapters_read: overview.chapters_read,
      total_chapters: overview.total_chapters
    })
    |> assign(:book_sections, book_sections)
    |> assign(:chapter_ids, chapter_ids)
    |> assign(:expanded_books, expanded_books)
    |> assign(:testament_filter, Map.get(socket.assigns, :testament_filter, :all))
  end

  defp testament_filters do
    [
      {:all, gettext("All")},
      {:old_testament, gettext("Old Testament")},
      {:new_testament, gettext("New Testament")}
    ]
  end

  defp filtered_sections(sections, :all), do: sections

  defp filtered_sections(sections, :old_testament) do
    Enum.filter(sections, fn %{book: book} -> book.testament == "ot" end)
  end

  defp filtered_sections(sections, :new_testament) do
    Enum.filter(sections, fn %{book: book} -> book.testament == "nt" end)
  end
end

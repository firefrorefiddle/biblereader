defmodule BibleReaderWeb.ReadingHomeLive do
  @moduledoc """
  Reading dashboard: continue reading, progress, pace, recently read, and book list.
  """
  use BibleReaderWeb, :live_view

  alias BibleReader.Accounts
  alias BibleReader.Notes
  alias BibleReader.ReadingPlan

  @impl true
  def render(assigns) do
    ~H"""
    <div class="reading-dashboard mx-auto max-w-3xl px-1 py-6 sm:px-2">
      <div class="mb-8 border-b border-zinc-200 pb-4">
        <h1 class="font-serif text-2xl font-semibold tracking-tight text-zinc-900">Today</h1>
      </div>

      <section class="mb-10">
        <%= if @continue do %>
          <.continue_card suggestion={@continue} timezone={@timezone} />
        <% else %>
          <div class="rounded-xl border border-zinc-200 bg-card p-5 shadow-sm">
            <p class="text-sm text-zinc-600">
              Log your first chapter from any book below to see a continue reading suggestion.
            </p>
          </div>
        <% end %>
      </section>

      <section class="mb-10">
        <h2 class="mb-3 text-sm font-semibold uppercase tracking-wide text-zinc-500">Progress</h2>
        <div class="grid grid-cols-3 gap-3">
          <.progress_stat
            value={to_string(@stats.distinct_chapters_read_at_least_once)}
            label="chapters read"
          />
          <.progress_stat value={to_string(@week_reads)} label="this week" />
          <.progress_stat value={to_string(@note_count)} label="notes" />
        </div>
      </section>

      <section class="mb-10">
        <.pace_summary pace={@pace} show_more?={@show_more_stats} />
      </section>

      <section :if={@recently != []} class="mb-10">
        <h2 class="mb-2 text-sm font-semibold uppercase tracking-wide text-zinc-500">
          Recently read
        </h2>
        <div class="rounded-xl border border-zinc-200 bg-card divide-y divide-zinc-100 shadow-sm">
          <%= for row <- @recently do %>
            <.recently_read_row
              book_name={row.book.name}
              chapter_number={row.chapter.chapter_number}
              age_label={row.age_label}
              read_count={row.read_count}
              book_code={row.book.code}
            />
          <% end %>
        </div>
      </section>

      <section>
        <h2 class="mb-3 text-sm font-semibold uppercase tracking-wide text-zinc-500">Books</h2>
        <div class="mb-4 flex flex-wrap gap-2">
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
        </div>
        <div class="space-y-2">
          <%= for row <- filtered_books(@book_progress, @testament_filter) do %>
            <.book_progress_row
              book={row.book}
              book_code={row.book.code}
              chapters_read={row.chapters_read}
              total_chapters={row.total_chapters}
            />
          <% end %>
        </div>
        <p class="mt-4 text-xs text-zinc-500">
          <.link navigate={~p"/users/settings"} class="text-primary hover:underline">
            Settings
          </.link>
          — include apocryphal books, timezone, and account.
        </p>
      </section>
    </div>
    """
  end

  @impl true
  def mount(_params, _session, socket) do
    {:ok, load_page(socket)}
  end

  @impl true
  def handle_event("toggle_more_stats", _params, socket) do
    {:noreply, assign(socket, :show_more_stats, !socket.assigns.show_more_stats)}
  end

  def handle_event("filter_testament", %{"filter" => filter}, socket) do
    filter = String.to_existing_atom(filter)
    {:noreply, assign(socket, :testament_filter, filter)}
  end

  defp load_page(socket) do
    user = Accounts.get_user!(socket.assigns.current_user.id)
    timezone = user.timezone || "Etc/UTC"
    stats = ReadingPlan.stats_for_user(user)
    pace = ReadingPlan.dashboard_pace_summary(user)
    continue = ReadingPlan.continue_reading(user)
    week_reads = ReadingPlan.chapters_read_in_window(user, 7)
    note_count = Notes.count_notes_for_user(user.id)

    recently =
      user
      |> ReadingPlan.recently_read_chapters(limit: 10)
      |> Enum.map(fn row ->
        Map.put(row, :age_label, ReadingPlan.relative_label(row.last_read_at, timezone))
      end)

    socket
    |> assign(:page_title, "Home")
    |> assign(:timezone, timezone)
    |> assign(:stats, stats)
    |> assign(:pace, pace)
    |> assign(:continue, continue)
    |> assign(:week_reads, week_reads)
    |> assign(:note_count, note_count)
    |> assign(:recently, recently)
    |> assign(:book_progress, ReadingPlan.book_progress_for_user(user))
    |> assign(:testament_filter, :all)
    |> assign(:show_more_stats, false)
  end

  defp testament_filters do
    [
      {:all, "All"},
      {:old_testament, "Old Testament"},
      {:new_testament, "New Testament"}
    ]
  end

  defp filtered_books(rows, :all), do: rows

  defp filtered_books(rows, :old_testament) do
    Enum.filter(rows, fn %{book: b} -> b.testament == "ot" end)
  end

  defp filtered_books(rows, :new_testament) do
    Enum.filter(rows, fn %{book: b} -> b.testament == "nt" end)
  end
end

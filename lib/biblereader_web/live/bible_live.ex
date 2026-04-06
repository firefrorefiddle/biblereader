defmodule BibleReaderWeb.BibleLive do
  @moduledoc """
  Authenticated view of the chapter catalog with read logging and rolling-window stats.
  """
  use BibleReaderWeb, :live_view

  alias BibleReader.Accounts
  alias BibleReader.ReadingPlan
  alias BibleReader.Scripture

  @impl true
  def render(assigns) do
    ~H"""
    <div class="reading-record px-1 py-6 sm:px-2">
      <div class="mb-6 border-b border-zinc-200 pb-4">
        <h1 class="font-serif text-2xl font-semibold tracking-tight text-zinc-900">
          Bible reading record
        </h1>
        <p class="mt-1 text-sm text-zinc-600">
          Click a chapter number to log a read (paper-style chart). Highlighted cells have been read at least once.
        </p>
      </div>

      <div class="mb-8 rounded-lg border border-zinc-200 bg-zinc-50 p-4 text-sm text-zinc-800">
        <h2 class="text-base font-semibold text-zinc-900">Reading stats</h2>
        <p class="mt-2">
          Rolling window: <span class="font-medium">{@stats.rolling_days}</span> days.
          Chapters logged in window: <span class="font-medium">{@stats.chapters_read_in_window}</span>.
          Avg / day: <span class="font-medium">{Float.round(@stats.avg_chapters_per_day_in_window, 2)}</span>.
        </p>
        <p class="mt-1">
          Distinct chapters read at least once (in scope):
          <span class="font-medium">{@stats.distinct_chapters_read_at_least_once}</span>
          / {@stats.total_chapters_in_scope}.
        </p>
        <p :if={@stats.estimated_days_to_first_complete} class="mt-1">
          Estimated days to touch every chapter in scope at least once (at current pace):
          <span class="font-medium">{@stats.estimated_days_to_first_complete}</span>
        </p>
        <p :if={is_nil(@stats.estimated_days_to_first_complete)} class="mt-1 text-zinc-600">
          ETA unavailable until you log reads in the current window (pace is zero).
        </p>
      </div>

      <.form
        for={@prefs_form}
        id="prefs-form"
        phx-change="update_prefs"
        class="mb-8 flex flex-wrap items-center gap-4 border-b border-zinc-100 pb-6"
      >
        <label class="flex items-center gap-2 text-sm text-zinc-700">
          <.input field={@prefs_form[:show_apocrypha]} type="checkbox" />
          Show apocryphal / deuterocanonical books
        </label>
      </.form>

      <div class="space-y-10 print:space-y-8">
        <%= for book_row <- @book_rows do %>
          <section class="break-inside-avoid">
            <h2 class="mb-2 font-serif text-lg font-semibold text-zinc-900">
              {book_row.book.name}
            </h2>
            <%!-- Dense chapter grid: rows wrap like a printed reading chart (~20 chapters per row on wide screens) --%>
            <div class="inline-grid max-w-full gap-px rounded-sm border border-zinc-300 bg-white p-px [grid-template-columns:repeat(auto-fill,minmax(2rem,2.75rem))]">
              <%= for ch <- book_row.chapters do %>
                <button
                  type="button"
                  phx-click="log_read"
                  phx-value-chapter-id={ch.id}
                  title={"#{book_row.book.name} #{ch.number} — #{ch.read_count} read(s). Click to log another read."}
                  aria-label={"Log a read for #{book_row.book.name} chapter #{ch.number}, #{ch.read_count} times so far"}
                  class={[
                    "relative flex min-h-[2rem] min-w-[2rem] flex-col items-center justify-center border px-0.5 py-0.5 text-[11px] font-medium tabular-nums leading-none transition sm:min-h-[2.125rem] sm:min-w-[2.125rem] sm:text-xs",
                    if(ch.read_count > 0,
                      do:
                        "border-emerald-600 bg-emerald-100 text-emerald-950 hover:bg-emerald-200 focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-0 focus-visible:outline-emerald-700",
                      else:
                        "border-zinc-300 bg-white text-zinc-900 hover:border-emerald-500 hover:bg-emerald-50 focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-0 focus-visible:outline-emerald-600"
                    )
                  ]}
                >
                  <span>{ch.number}</span>
                  <span
                    :if={ch.read_count > 0}
                    class="mt-0.5 text-[9px] font-semibold leading-none text-emerald-800"
                  >
                    ×{ch.read_count}
                  </span>
                </button>
              <% end %>
            </div>
          </section>
        <% end %>
      </div>
    </div>
    """
  end

  @impl true
  def mount(_params, _session, socket) do
    {:ok, load_page(socket)}
  end

  defp load_page(socket) do
    user = Accounts.get_user!(socket.assigns.current_user.id)
    stats = ReadingPlan.stats_for_user(user)
    book_rows = build_book_rows(user)
    prefs_form = to_form(%{"show_apocrypha" => user.show_apocrypha}, as: :prefs)

    socket
    |> assign(:stats, stats)
    |> assign(:book_rows, book_rows)
    |> assign(:prefs_form, prefs_form)
  end

  defp build_book_rows(user) do
    counts = ReadingPlan.read_counts_by_chapter_id(user.id)

    user
    |> Scripture.list_books_for_user()
    |> Enum.map(fn book ->
      chapters =
        book.id
        |> Scripture.list_chapters_for_book()
        |> Enum.map(fn ch ->
          %{
            id: ch.id,
            number: ch.chapter_number,
            read_count: Map.get(counts, ch.id, 0)
          }
        end)

      %{book: book, chapters: chapters}
    end)
  end

  @impl true
  def handle_event("log_read", %{"chapter-id" => id}, socket) do
    chapter_id = String.to_integer(id)

    case ReadingPlan.log_chapter_read(socket.assigns.current_user, chapter_id) do
      {:ok, _} ->
        {:noreply, load_page(socket)}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Could not log read.")}
    end
  end

  def handle_event("update_prefs", params, socket) do
    show =
      case get_in(params, ["prefs", "show_apocrypha"]) do
        "true" -> true
        _ -> false
      end

    case Accounts.update_user_reading_profile(socket.assigns.current_user, %{show_apocrypha: show}) do
      {:ok, user} ->
        socket =
          socket
          |> assign(:current_user, user)
          |> load_page()

        {:noreply, socket}

      {:error, %Ecto.Changeset{}} ->
        {:noreply, put_flash(socket, :error, "Could not update preferences.")}
    end
  end
end

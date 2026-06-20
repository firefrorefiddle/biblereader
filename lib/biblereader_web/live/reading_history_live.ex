defmodule BibleReaderWeb.ReadingHistoryLive do
  @moduledoc """
  Reading history for the last seven calendar days in the user's profile timezone.
  """
  use BibleReaderWeb, :live_view

  alias BibleReader.Accounts
  alias BibleReader.ReadingPlan
  alias BibleReader.ReadingPlan.RelativeTime
  alias BibleReader.Scripture
  alias BibleReaderWeb.RelativeTimeFormat
  alias BibleReaderWeb.EffectiveDate, as: EffectiveDateUI

  @week_days 7

  @impl true
  def render(assigns) do
    ~H"""
    <div class="reading-history mx-auto max-w-3xl px-1 py-6 sm:px-2">
      <div class="mb-8 border-b border-zinc-200 pb-4">
        <h1 class="font-serif text-2xl font-semibold tracking-tight text-zinc-900">
          {gettext("Reading history")}
        </h1>
        <p class="mt-1 text-sm text-zinc-600">
          {gettext("Chapters you read in the last %{days} days.", days: @week_days)}
        </p>
      </div>

      <div
        :if={@days == []}
        class="rounded-xl border border-zinc-200 bg-card p-6 text-sm text-zinc-600 shadow-sm"
      >
        {gettext("No chapters read in the last %{days} days.", days: @week_days)}
      </div>

      <div :if={@days != []} class="space-y-8">
        <%= for day <- @days do %>
          <section>
            <h2 class="mb-2 text-sm font-semibold uppercase tracking-wide text-zinc-500">
              {day.heading}
            </h2>
            <div class="rounded-xl border border-zinc-200 bg-card divide-y divide-zinc-100 shadow-sm">
              <%= for row <- day.rows do %>
                <.history_read_row
                  book_name={row.book_name}
                  chapter_number={row.chapter_number}
                  read_at_label={row.read_at_label}
                  book_code={row.book_code}
                />
              <% end %>
            </div>
          </section>
        <% end %>
      </div>

      <p class="mt-8 text-sm">
        <.link navigate={~p"/read"} class="text-primary hover:underline">
          ← {gettext("Back to home")}
        </.link>
      </p>
    </div>
    """
  end

  @impl true
  def mount(_params, _session, socket) do
    {:ok, load_page(socket)}
  end

  @impl true
  def handle_event("open_effective_date_picker", _params, socket) do
    {:noreply, EffectiveDateUI.open_picker(socket)}
  end

  def handle_event("close_effective_date_picker", _params, socket) do
    {:noreply, EffectiveDateUI.close_picker(socket)}
  end

  defp load_page(socket) do
    user = Accounts.get_user!(socket.assigns.current_user.id)
    locale = socket.assigns.locale
    timezone = user.timezone || "Etc/UTC"

    days =
      user
      |> ReadingPlan.recent_read_events_by_day(window_days: @week_days)
      |> Enum.map(fn day ->
        %{
          heading: day_heading(day.day_label, locale),
          rows:
            Enum.map(day.events, fn event ->
              book = event.chapter.book

              %{
                book_name: Scripture.book_display_name(book, locale),
                chapter_number: event.chapter.chapter_number,
                book_code: book.code,
                read_at_label: RelativeTime.format_datetime(event.read_at, timezone, locale)
              }
            end)
        }
      end)

    socket
    |> assign(:page_title, gettext("Reading history"))
    |> assign(:locale_return_to, ~p"/read/history")
    |> assign(:week_days, @week_days)
    |> assign(:days, days)
  end

  defp day_heading(:today, _locale), do: gettext("Today")
  defp day_heading(:yesterday, _locale), do: gettext("Yesterday")
  defp day_heading(label, locale), do: RelativeTimeFormat.format(label, locale)
end

defmodule BibleReaderWeb.ReadingComponents do
  @moduledoc """
  UI components for the reading companion workflow (dashboard, book grid, chapter view).
  """
  use Phoenix.Component
  use Gettext, backend: BibleReaderWeb.Gettext
  use BibleReaderWeb, :verified_routes

  alias BibleReader.ReadingPlan
  alias BibleReaderWeb.RelativeTimeFormat

  @bucket_classes %{
    unread: "border-zinc-300 bg-white text-zinc-900 hover:border-primary hover:bg-primary-muted",
    today:
      "border-emerald-700 bg-emerald-200 text-emerald-950 hover:bg-emerald-300 focus-visible:outline-emerald-800",
    week: "border-emerald-500 bg-emerald-50 text-emerald-900 hover:bg-emerald-100",
    month: "border-teal-400 bg-teal-50 text-teal-900 hover:bg-teal-100",
    older: "border-amber-300/80 bg-amber-50/80 text-amber-950 hover:bg-amber-100"
  }

  attr :suggestion, :map, required: true
  attr :timezone, :string, required: true
  attr :locale, :string, required: true
  attr :book_name, :string, required: true

  def continue_card(assigns) do
    %{chapter: chapter, last_read: last_read} = assigns.suggestion

    last_line =
      if last_read do
        chapter = last_read.chapter

        age =
          last_read.read_at
          |> ReadingPlan.relative_label(assigns.timezone)
          |> RelativeTimeFormat.format(assigns.locale)

        gettext("Last read: %{book} %{chapter} · %{age}",
          book: assigns.book_name,
          chapter: chapter.chapter_number,
          age: age
        )
      else
        gettext("Start your reading journey")
      end

    assigns =
      assigns
      |> assign(:chapter, chapter)
      |> assign(:last_line, last_line)

    ~H"""
    <div class="rounded-xl border border-zinc-200 bg-card p-5 shadow-sm">
      <p class="text-xs font-medium uppercase tracking-wide text-zinc-500">
        {gettext("Continue reading")}
      </p>
      <h2 class="mt-1 font-serif text-xl font-semibold text-zinc-900">
        {@book_name} {@chapter.chapter_number}
      </h2>
      <p class="mt-1 text-sm text-zinc-600">{@last_line}</p>
      <.link
        navigate={~p"/read/books/#{@suggestion.book.code}/#{@chapter.chapter_number}"}
        class="mt-4 inline-flex rounded-lg bg-primary px-4 py-2.5 text-sm font-medium text-white hover:bg-primary/90"
      >
        {gettext("Open chapter")}
      </.link>
    </div>
    """
  end

  attr :label, :string, required: true
  attr :value, :string, required: true

  def progress_stat(assigns) do
    ~H"""
    <div class="rounded-xl border border-zinc-200 bg-card p-4 text-center shadow-sm">
      <p class="font-serif text-2xl font-semibold text-zinc-900">{@value}</p>
      <p class="mt-1 text-xs text-zinc-600">{@label}</p>
    </div>
    """
  end

  attr :book_name, :string, required: true
  attr :chapters_read, :integer, required: true
  attr :total_chapters, :integer, required: true
  attr :book_code, :string, required: true

  def book_progress_row(assigns) do
    pct =
      if assigns.total_chapters > 0,
        do: assigns.chapters_read / assigns.total_chapters * 100,
        else: 0

    assigns = assign(assigns, :pct, pct)

    ~H"""
    <.link
      navigate={~p"/read/books/#{@book_code}"}
      class="flex items-center gap-4 rounded-lg border border-zinc-100 bg-card px-4 py-3 shadow-sm transition hover:border-zinc-200 hover:shadow"
    >
      <span class="min-w-0 flex-1 font-medium text-zinc-900">{@book_name}</span>
      <span class="shrink-0 text-sm tabular-nums text-zinc-600">
        {gettext("%{read}/%{total} read",
          read: @chapters_read,
          total: @total_chapters
        )}
      </span>
      <div class="h-2 w-24 shrink-0 overflow-hidden rounded-full bg-zinc-100">
        <div class="h-full rounded-full bg-primary" style={"width: #{@pct}%"} />
      </div>
    </.link>
    """
  end

  attr :number, :integer, required: true
  attr :read_count, :integer, required: true
  attr :age_label, :string, default: nil
  attr :bucket, :atom, required: true
  attr :has_note?, :boolean, default: false
  attr :to, :string, required: true
  attr :book_name, :string, required: true

  def chapter_cell(assigns) do
    base = Map.fetch!(@bucket_classes, assigns.bucket)

    assigns = assign(assigns, :cell_class, base)

    ~H"""
    <.link
      navigate={@to}
      title={gettext("%{book} %{number}", book: @book_name, number: @number)}
      aria-label={gettext("%{book} chapter %{number}", book: @book_name, number: @number)}
      class={[
        "relative flex min-h-[2rem] min-w-[2rem] flex-col items-center justify-center border px-0.5 py-0.5 text-[11px] font-medium tabular-nums leading-none transition sm:min-h-[2.125rem] sm:min-w-[2.125rem] sm:text-xs",
        @cell_class,
        "focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-0"
      ]}
    >
      <span
        :if={@has_note?}
        class="absolute right-0.5 top-0.5 hidden h-1.5 w-1.5 rounded-full bg-accent sm:block"
      />
      <span>{@number}</span>
      <span :if={@age_label} class="mt-0.5 text-[9px] font-normal leading-none opacity-90">
        {@age_label}
      </span>
      <span
        :if={@read_count > 1}
        class="mt-0.5 hidden text-[9px] font-semibold leading-none sm:inline"
      >
        ×{@read_count}
      </span>
    </.link>
    """
  end

  attr :book_name, :string, required: true
  attr :chapter_number, :integer, required: true
  attr :age_label, :string, required: true
  attr :read_count, :integer, required: true
  attr :book_code, :string, required: true

  def recently_read_row(assigns) do
    ~H"""
    <.link
      navigate={~p"/read/books/#{@book_code}/#{@chapter_number}"}
      class="flex items-center justify-between gap-4 rounded-lg px-2 py-2.5 text-sm hover:bg-zinc-50"
    >
      <span class="font-medium text-zinc-900">{@book_name} {@chapter_number}</span>
      <span class="flex shrink-0 items-center gap-3 tabular-nums text-zinc-600">
        <span>{@age_label}</span>
        <span :if={@read_count > 0} class="text-zinc-500">×{@read_count}</span>
      </span>
    </.link>
    """
  end

  attr :pace, :map, required: true
  attr :show_more?, :boolean, required: true

  def pace_summary(assigns) do
    ~H"""
    <div class="rounded-xl border border-zinc-200 bg-card p-5 shadow-sm">
      <h2 class="text-sm font-semibold text-zinc-900">{gettext("Current pace")}</h2>
      <p class="mt-2 text-sm text-zinc-700">
        {pace_line(@pace)}
      </p>
      <p :if={!@pace.has_pace} class="mt-2 text-sm text-zinc-600">
        {gettext("At this pace, full coverage would take a very long time.")}
        <span class="block mt-1 text-primary">
          {gettext("Try a small goal: 3 chapters per week.")}
        </span>
      </p>
      <p :if={@pace.has_pace and @pace.remaining > 0} class="mt-2 text-sm text-zinc-600">
        {coverage_line(@pace)}
      </p>
      <button
        type="button"
        phx-click="toggle_more_stats"
        class="mt-3 text-sm font-medium text-primary hover:underline"
      >
        {if @show_more?, do: gettext("Hide stats"), else: gettext("More stats")}
      </button>
      <.more_stats :if={@show_more?} pace={@pace} />
    </div>
    """
  end

  attr :pace, :map, required: true

  def more_stats(assigns) do
    ~H"""
    <div class="mt-4 border-t border-zinc-100 pt-4 text-sm text-zinc-700 space-y-1">
      <p>
        {gettext("Distinct chapters read: %{read} / %{total}",
          read: @pace.distinct_read,
          total: @pace.total_in_scope
        )}
      </p>
      <p :if={@pace.remaining > 0}>
        {gettext("Chapters not yet read at least once: %{count}", count: @pace.remaining)}
      </p>
      <p :if={eta_text(@pace.friendly_eta)}>
        {gettext("At this pace, first time through every chapter in scope: %{eta}",
          eta: eta_text(@pace.friendly_eta)
        )}
      </p>
    </div>
    """
  end

  def chapter_grid_legend(assigns) do
    ~H"""
    <p class="mt-4 text-xs text-zinc-600">
      <span class="font-medium">{gettext("Legend:")}</span>
      {gettext(
        "empty = unread · strong green = today · soft green = < 7 days · teal = < 30 days · pale = older"
      )}
    </p>
    """
  end

  defp pace_line(%{chapters_in_window: n, rolling_days: d}) do
    gettext("%{count} chapters in the last %{days} days", count: n, days: d)
  end

  defp coverage_line(%{friendly_eta: :very_long}) do
    gettext("At this pace, full coverage would take a very long time.")
  end

  defp coverage_line(%{friendly_eta: days}) when is_integer(days) do
    gettext("At this pace, touching every chapter in scope at least once: about %{days} days.",
      days: days
    )
  end

  defp coverage_line(_), do: nil

  defp eta_text(:very_long), do: gettext("a very long time")
  defp eta_text(days) when is_integer(days), do: gettext("about %{days} days", days: days)
  defp eta_text(_), do: nil
end

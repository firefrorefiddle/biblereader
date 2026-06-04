defmodule BibleReader.ReadingPlan do
  @moduledoc """
  User reading history: append-only **chapter read** events and derived statistics.

  ## Rolling window

  Pace and “chapters in window” use **`rolling_days`** (default **30**). Each stat
  documents the formula in `@doc`.

  ## Continue reading

  After the user's most recent read in canon scope:

  1. If that chapter is not the book's last → suggest same book, `chapter_number + 1`.
  2. If it is the last chapter → suggest chapter 1 of the next visible book by `sort_order`.
  3. If there is no next book → `nil`.

  ## ETA

  **Estimated days to first complete** the visible canon: distinct chapters never read
  at least once, divided by average chapters per day in the rolling window (if
  pace &gt; 0).
  """

  import Ecto.Query

  alias BibleReader.Repo
  alias BibleReader.Accounts.User
  alias BibleReader.ReadingPlan.{ChapterRead, RelativeTime}
  alias BibleReader.Scripture
  alias BibleReader.Scripture.{Book, Chapter}

  @default_rolling_days 30
  @week_window_days 7

  @doc """
  Inserts a read event for `chapter_id` as the given user. `read_at` defaults to now (UTC).
  """
  def log_chapter_read(%User{id: user_id}, chapter_id, read_at \\ nil) do
    read_at = read_at || DateTime.utc_now() |> DateTime.truncate(:microsecond)

    %ChapterRead{}
    |> ChapterRead.changeset(%{
      user_id: user_id,
      chapter_id: chapter_id,
      read_at: read_at
    })
    |> Repo.insert()
  end

  @doc """
  Map of `chapter_id` => total read count for this user (all time).
  """
  def read_counts_by_chapter_id(user_id) when is_integer(user_id) do
    from(cr in ChapterRead,
      where: cr.user_id == ^user_id,
      group_by: cr.chapter_id,
      select: {cr.chapter_id, count(cr.id)}
    )
    |> Repo.all()
    |> Map.new()
  end

  @doc """
  Map of `chapter_id` => most recent `read_at` for this user.
  """
  def last_read_at_by_chapter_id(user_id) when is_integer(user_id) do
    from(cr in ChapterRead,
      where: cr.user_id == ^user_id,
      group_by: cr.chapter_id,
      select: {cr.chapter_id, max(cr.read_at)}
    )
    |> Repo.all()
    |> Map.new()
  end

  @doc """
  Read events for one chapter, newest first.
  """
  def read_events_for_chapter(user_id, chapter_id)
      when is_integer(user_id) and is_integer(chapter_id) do
    from(cr in ChapterRead,
      where: cr.user_id == ^user_id and cr.chapter_id == ^chapter_id,
      order_by: [desc: cr.read_at]
    )
    |> Repo.all()
  end

  @doc """
  Count of read events in the last `window_days` days (default #{@week_window_days}).
  """
  def chapters_read_in_window(%User{id: user_id}, window_days \\ @week_window_days) do
    now = DateTime.utc_now()
    window_start = DateTime.add(now, -window_days * 86_400, :second)

    from(cr in ChapterRead,
      where: cr.user_id == ^user_id and cr.read_at >= ^window_start and cr.read_at <= ^now,
      select: count(cr.id)
    )
    |> Repo.one()
  end

  @doc """
  Chapters the user has read recently: one row per chapter (latest `read_at`),
  preloaded with `chapter: :book`, ordered newest first.
  """
  def recently_read_chapters(%User{} = user, opts \\ []) do
    limit = Keyword.get(opts, :limit, 10)
    scope_ids = chapter_ids_in_scope(user)

    if scope_ids == [] do
      []
    else
      latest =
        from(cr in ChapterRead,
          where: cr.user_id == ^user.id and cr.chapter_id in ^scope_ids,
          group_by: cr.chapter_id,
          select: %{chapter_id: cr.chapter_id, last_read_at: max(cr.read_at)}
        )

      counts = read_counts_by_chapter_id(user.id)

      from(l in subquery(latest),
        join: c in Chapter,
        on: c.id == l.chapter_id,
        join: b in Book,
        on: b.id == c.book_id,
        order_by: [desc: l.last_read_at],
        limit: ^limit,
        select: {c, b, l.last_read_at}
      )
      |> Repo.all()
      |> Enum.map(fn {chapter, book, last_read_at} ->
        %{
          chapter: chapter,
          book: book,
          last_read_at: last_read_at,
          read_count: Map.get(counts, chapter.id, 0)
        }
      end)
    end
  end

  @doc """
  Suggests the next chapter to read, or `nil`.

  Returns `%{book: book, chapter: chapter, last_read: last_read_event | nil}` where
  `last_read` is the most recent read that informed the suggestion.
  """
  def continue_reading(%User{} = user) do
    scope_ids = chapter_ids_in_scope(user)

    last =
      from(cr in ChapterRead,
        where: cr.user_id == ^user.id and cr.chapter_id in ^scope_ids,
        order_by: [desc: cr.read_at],
        limit: 1,
        preload: [chapter: :book]
      )
      |> Repo.one()

    if is_nil(last) do
      first_chapter_in_scope(user)
    else
      suggest_after_read(user, last)
    end
  end

  defp suggest_after_read(user, %ChapterRead{chapter: %{chapter_number: n, book: book}} = last) do
    max_chapter = max_chapter_number(book.id)

    if n < max_chapter do
      case Scripture.get_chapter_by_code_and_number(book.code, n + 1) do
        %Chapter{} = chapter ->
          %{book: book, chapter: chapter, last_read: last}

        nil ->
          nil
      end
    else
      next_book_first_chapter(user, book)
    end
  end

  defp next_book_first_chapter(user, %Book{} = current) do
    books = Scripture.list_books_for_user(user)

    case Enum.drop_while(books, &(&1.id != current.id)) do
      [_current | rest] ->
        case rest do
          [%Book{code: code} = book | _] ->
            case Scripture.get_chapter_by_code_and_number(code, 1) do
              %Chapter{} = chapter -> %{book: book, chapter: chapter, last_read: nil}
              nil -> nil
            end

          [] ->
            nil
        end

      _ ->
        nil
    end
  end

  defp first_chapter_in_scope(user) do
    case Scripture.list_books_for_user(user) do
      [%Book{code: code} = book | _] ->
        case Scripture.get_chapter_by_code_and_number(code, 1) do
          %Chapter{} = chapter -> %{book: book, chapter: chapter, last_read: nil}
          nil -> nil
        end

      [] ->
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

  @doc """
  Per-book progress for dashboard: chapters read, totals, last read in book.
  """
  def book_progress_for_user(%User{} = user) do
    counts = read_counts_by_chapter_id(user.id)
    last_at = last_read_at_by_chapter_id(user.id)
    timezone = user.timezone || "Etc/UTC"

    user
    |> Scripture.list_books_for_user()
    |> Enum.map(fn book ->
      chapters = Scripture.list_chapters_for_book(book.id)
      total = length(chapters)

      read_count =
        chapters
        |> Enum.count(fn ch -> Map.get(counts, ch.id, 0) > 0 end)

      {last_chapter, last_read_at} =
        chapters
        |> Enum.filter(fn ch -> Map.has_key?(last_at, ch.id) end)
        |> Enum.map(fn ch -> {ch, Map.get(last_at, ch.id)} end)
        |> Enum.max_by(fn {_ch, at} -> at end, fn -> {nil, nil} end)

      %{
        book: book,
        chapters_read: read_count,
        total_chapters: total,
        last_chapter_number: last_chapter && last_chapter.chapter_number,
        last_read_at: last_read_at,
        last_read_label:
          if(last_read_at, do: RelativeTime.label(last_read_at, timezone), else: nil)
      }
    end)
  end

  @doc """
  Friendly pace summary for the home dashboard (default #{@default_rolling_days}-day window).
  """
  def dashboard_pace_summary(%User{} = user, opts \\ []) do
    rolling_days = Keyword.get(opts, :rolling_days, @default_rolling_days)
    stats = stats_for_user(user, rolling_days: rolling_days)

    %{
      rolling_days: rolling_days,
      chapters_in_window: stats.chapters_read_in_window,
      has_pace: stats.avg_chapters_per_day_in_window > 0,
      distinct_read: stats.distinct_chapters_read_at_least_once,
      total_in_scope: stats.total_chapters_in_scope,
      remaining: stats.chapters_remaining_to_touch_once,
      eta_days: stats.estimated_days_to_first_complete,
      friendly_eta: friendly_eta(stats.estimated_days_to_first_complete)
    }
  end

  @doc """
  Statistics for the dashboard.

  * **`rolling_days`** — window length (default `#{@default_rolling_days}`).
  * **`chapters_read_in_window`** — count of read *events* with `read_at` in `[now - window, now]`.
  * **`avg_chapters_per_day_in_window`** — `chapters_read_in_window / rolling_days`.
  * **`distinct_chapters_read_ever`** — distinct `chapter_id` with ≥1 read, limited to chapters in `visible_chapter_ids` if provided.
  * **`total_chapters_in_scope`** — number of chapters in scope (Protestant-only or including apocrypha per user).
  * **`estimated_days_to_first_complete`** — `(total_in_scope - distinct_read_at_least_once) / avg_per_day` when avg &gt; 0, else `nil`.
  """
  def stats_for_user(%User{} = user, opts \\ []) do
    rolling_days = Keyword.get(opts, :rolling_days, @default_rolling_days)
    now = DateTime.utc_now()
    window_start = DateTime.add(now, -rolling_days * 86_400, :second)

    chapters_read_in_window =
      from(cr in ChapterRead,
        where: cr.user_id == ^user.id and cr.read_at >= ^window_start and cr.read_at <= ^now,
        select: count(cr.id)
      )
      |> Repo.one()

    avg = if rolling_days > 0, do: chapters_read_in_window / rolling_days, else: 0.0

    scope_chapter_ids = chapter_ids_in_scope(user)
    total_in_scope = length(scope_chapter_ids)

    distinct_read =
      from(cr in ChapterRead,
        where: cr.user_id == ^user.id,
        select: cr.chapter_id,
        distinct: true
      )
      |> Repo.all()
      |> MapSet.new()
      |> MapSet.intersection(MapSet.new(scope_chapter_ids))
      |> MapSet.size()

    remaining = max(total_in_scope - distinct_read, 0)

    eta_days =
      if avg > 0 and remaining > 0 do
        ceil(remaining / avg)
      else
        nil
      end

    %{
      rolling_days: rolling_days,
      chapters_read_in_window: chapters_read_in_window,
      avg_chapters_per_day_in_window: avg,
      distinct_chapters_read_at_least_once: distinct_read,
      total_chapters_in_scope: total_in_scope,
      chapters_remaining_to_touch_once: remaining,
      estimated_days_to_first_complete: eta_days
    }
  end

  @doc """
  Delegates to `RelativeTime.age_bucket/3`.
  """
  def age_bucket(read_count, last_read_at, timezone),
    do: RelativeTime.age_bucket(read_count, last_read_at, timezone)

  @doc """
  Structured relative label; format for display with `BibleReaderWeb.RelativeTimeFormat.format/2`.
  """
  def relative_label(read_at, timezone), do: RelativeTime.label(read_at, timezone)

  defp friendly_eta(nil), do: nil
  defp friendly_eta(days) when days > 365 * 5, do: :very_long
  defp friendly_eta(days), do: days

  defp chapter_ids_in_scope(%User{show_apocrypha: true}) do
    from(c in Chapter,
      join: b in Book,
      on: c.book_id == b.id,
      where: b.in_protestant_canon == true or b.in_apocrypha == true,
      select: c.id
    )
    |> Repo.all()
  end

  defp chapter_ids_in_scope(%User{show_apocrypha: false}) do
    from(c in Chapter,
      join: b in Book,
      on: c.book_id == b.id,
      where: b.in_protestant_canon == true,
      select: c.id
    )
    |> Repo.all()
  end
end

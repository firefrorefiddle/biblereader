defmodule BibleReader.ReadingPlan do
  @moduledoc """
  User reading history: append-only **chapter read** events and derived statistics.

  ## Rolling window

  Pace and “chapters in window” use **`rolling_days`** (default **30**). Each stat
  documents the formula in `@doc`.

  ## ETA

  **Estimated days to first complete** the visible canon: distinct chapters never read
  at least once, divided by average chapters per day in the rolling window (if
  pace &gt; 0).
  """

  import Ecto.Query

  alias BibleReader.Repo
  alias BibleReader.Accounts.User
  alias BibleReader.ReadingPlan.ChapterRead
  alias BibleReader.Scripture.{Book, Chapter}

  @default_rolling_days 30

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

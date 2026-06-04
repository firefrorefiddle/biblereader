defmodule BibleReader.ReadingPlan.RelativeTime do
  @moduledoc """
  Human-readable relative ages and styling buckets for chapter reads,
  using the user's profile timezone for calendar-day comparisons.
  """

  @doc """
  Short label for UI: `today`, `1d`, `12d`, `2mo`, etc.
  """
  def label(%DateTime{} = read_at, timezone) when is_binary(timezone) do
    read_day = read_at |> shift_to_zone(timezone) |> DateTime.to_date()
    today = today_in_zone(timezone)
    days = Date.diff(today, read_day)

    cond do
      days == 0 -> "today"
      days == 1 -> "yesterday"
      days < 7 -> "#{days}d"
      days < 30 -> "#{days}d"
      days < 365 -> "#{div(days, 30)}mo"
      true -> "#{div(days, 365)}y"
    end
  end

  def label(nil, _timezone), do: nil

  @doc """
  Styling bucket from last read instant and read count.

  * `:unread` — never read
  * `:today`, `:week`, `:month`, `:older` — based on calendar days in user TZ
  """
  def age_bucket(read_count, last_read_at, timezone)
      when is_integer(read_count) and is_binary(timezone) do
    cond do
      read_count == 0 or is_nil(last_read_at) -> :unread
      true -> bucket_for_date(last_read_at, timezone)
    end
  end

  defp bucket_for_date(%DateTime{} = read_at, timezone) do
    read_day = read_at |> shift_to_zone(timezone) |> DateTime.to_date()
    today = today_in_zone(timezone)
    days = Date.diff(today, read_day)

    cond do
      days == 0 -> :today
      days < 7 -> :week
      days < 30 -> :month
      true -> :older
    end
  end

  @doc """
  Formats `read_at` for history lists in the user's timezone.
  """
  def format_datetime(%DateTime{} = dt, timezone) do
    dt
    |> shift_to_zone(timezone)
    |> Calendar.strftime("%b %-d, %Y at %-I:%M %p")
  end

  defp today_in_zone(timezone) do
    DateTime.utc_now()
    |> shift_to_zone(timezone)
    |> DateTime.to_date()
  end

  defp shift_to_zone(%DateTime{} = dt, timezone) do
    case DateTime.shift_zone(dt, timezone, Tzdata.TimeZoneDatabase) do
      {:ok, local} -> local
      {:error, _} -> dt
    end
  end
end

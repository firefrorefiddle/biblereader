defmodule BibleReader.ReadingPlan.RelativeTime do
  @moduledoc """
  Relative ages and styling buckets for chapter reads,
  using the user's profile timezone for calendar-day comparisons.

  `label/2` returns structured values for localization in the web layer.
  """

  alias BibleReader.I18n.CalendarFormat

  @type label ::
          :today
          | :yesterday
          | {:days, pos_integer()}
          | {:months, pos_integer()}
          | {:years, pos_integer()}

  @doc """
  Structured label for UI: `:today`, `:yesterday`, `{:days, n}`, etc.
  """
  @spec label(DateTime.t() | nil, String.t()) :: label() | nil
  def label(%DateTime{} = read_at, timezone) when is_binary(timezone) do
    label_for_date(date_in_zone(read_at, timezone), timezone)
  end

  def label(nil, _timezone), do: nil

  @doc """
  Calendar date for `read_at` in the given IANA timezone.
  """
  @spec date_in_zone(DateTime.t(), String.t()) :: Date.t()
  def date_in_zone(%DateTime{} = dt, timezone) when is_binary(timezone) do
    dt |> shift_to_zone(timezone) |> DateTime.to_date()
  end

  @doc """
  Today's calendar date in the given IANA timezone.
  """
  @spec today_in_zone(String.t()) :: Date.t()
  def today_in_zone(timezone) when is_binary(timezone) do
    DateTime.utc_now()
    |> shift_to_zone(timezone)
    |> DateTime.to_date()
  end

  @doc """
  UTC instant for midnight at the start of `day` in `timezone`.
  """
  @spec start_of_day_utc(Date.t(), String.t()) :: DateTime.t()
  def start_of_day_utc(%Date{} = day, timezone) when is_binary(timezone) do
    case DateTime.new(day, ~T[00:00:00], timezone, Tzdata.TimeZoneDatabase) do
      {:ok, local} ->
        case DateTime.shift_zone(local, "Etc/UTC", Tzdata.TimeZoneDatabase) do
          {:ok, utc} -> utc
          {:error, _} -> DateTime.utc_now()
        end

      {:error, _} ->
        DateTime.utc_now()
    end
  end

  @doc """
  Structured day heading for a calendar date relative to today in `timezone`.
  """
  @spec label_for_date(Date.t(), String.t()) :: label()
  def label_for_date(%Date{} = date, timezone) when is_binary(timezone) do
    days = Date.diff(today_in_zone(timezone), date)

    cond do
      days == 0 -> :today
      days == 1 -> :yesterday
      days < 30 -> {:days, days}
      days < 365 -> {:months, div(days, 30)}
      true -> {:years, div(days, 365)}
    end
  end

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
    read_day = date_in_zone(read_at, timezone)
    days = Date.diff(today_in_zone(timezone), read_day)

    cond do
      days == 0 -> :today
      days < 7 -> :week
      days < 30 -> :month
      true -> :older
    end
  end

  @doc """
  Formats `read_at` for history lists using a locale-specific pattern.
  """
  @spec format_datetime(DateTime.t(), String.t(), String.t()) :: String.t()
  def format_datetime(%DateTime{} = dt, timezone, locale) do
    dt
    |> shift_to_zone(timezone)
    |> CalendarFormat.format_datetime(locale)
  end

  defp shift_to_zone(%DateTime{} = dt, timezone) do
    case DateTime.shift_zone(dt, timezone, Tzdata.TimeZoneDatabase) do
      {:ok, local} -> local
      {:error, _} -> dt
    end
  end
end

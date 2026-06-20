defmodule BibleReader.ReadingPlan.EffectiveDate do
  @moduledoc """
  Validates and converts **effective read dates** for backdating chapter logs.

  Users may choose a calendar day within the last seven days (in their profile
  timezone). Reads logged on an effective date are stored with `read_at` set to
  **12:00 (noon) local time** on that day (converted to UTC). When the effective
  date is **today**, `read_at` is the current UTC instant instead.

  This aligns with the seven-day reading history window.
  """

  alias BibleReader.ReadingPlan.RelativeTime

  @window_days 7

  @doc "Number of calendar days (including today) selectable for backdating."
  def window_days, do: @window_days

  @doc """
  Returns `{:ok, date}` when `date` is today or within the last #{@window_days - 1} days
  in `timezone`; otherwise `{:error, reason}` (`:future`, `:too_old`, or `:invalid`).
  """
  @spec validate(Date.t(), String.t()) :: {:ok, Date.t()} | {:error, atom()}
  def validate(%Date{} = date, timezone) when is_binary(timezone) do
    today = RelativeTime.today_in_zone(timezone)
    earliest = Date.add(today, -(@window_days - 1))

    cond do
      Date.compare(date, today) == :gt ->
        {:error, :future}

      Date.compare(date, earliest) == :lt ->
        {:error, :too_old}

      true ->
        {:ok, date}
    end
  end

  @doc """
  Parses an ISO8601 date string and validates it in `timezone`.
  """
  @spec validate_string(String.t(), String.t()) :: {:ok, Date.t()} | {:error, atom()}
  def validate_string(date_str, timezone) when is_binary(date_str) and is_binary(timezone) do
    case Date.from_iso8601(date_str) do
      {:ok, date} -> validate(date, timezone)
      {:error, _} -> {:error, :invalid}
    end
  end

  @doc """
  UTC `read_at` for logging against `effective_date` in `timezone`.
  """
  @spec read_at_for(Date.t(), String.t()) :: DateTime.t()
  def read_at_for(%Date{} = effective_date, timezone) when is_binary(timezone) do
    today = RelativeTime.today_in_zone(timezone)

    if Date.compare(effective_date, today) == :eq do
      DateTime.utc_now() |> DateTime.truncate(:microsecond)
    else
      noon_utc(effective_date, timezone)
    end
  end

  @doc """
  Calendar dates selectable in the picker: today and the prior #{@window_days - 1} days.
  """
  @spec selectable_dates(String.t()) :: [Date.t()]
  def selectable_dates(timezone) when is_binary(timezone) do
    today = RelativeTime.today_in_zone(timezone)

    Enum.map(0..(@window_days - 1), fn offset ->
      Date.add(today, -offset)
    end)
  end

  @doc "True when `date` is set and not today in `timezone`."
  @spec active?(Date.t() | nil, String.t()) :: boolean()
  def active?(nil, _timezone), do: false

  def active?(%Date{} = date, timezone) when is_binary(timezone) do
    date != RelativeTime.today_in_zone(timezone)
  end

  @doc "Long formatted date for banners, e.g. \"Monday, Jun 16\"."
  @spec format_long(Date.t(), String.t()) :: String.t()
  def format_long(%Date{} = date, locale) when is_binary(locale) do
    Calendar.strftime(date, long_date_pattern(locale))
  end

  defp long_date_pattern("de"), do: "%A, %d. %B"
  defp long_date_pattern(_), do: "%A, %b %-d"

  defp noon_utc(%Date{} = day, timezone) do
    case DateTime.new(day, ~T[12:00:00], timezone, Tzdata.TimeZoneDatabase) do
      {:ok, local} ->
        case DateTime.shift_zone(local, "Etc/UTC", Tzdata.TimeZoneDatabase) do
          {:ok, utc} -> DateTime.truncate(utc, :microsecond)
          {:error, _} -> DateTime.utc_now() |> DateTime.truncate(:microsecond)
        end

      {:error, _} ->
        DateTime.utc_now() |> DateTime.truncate(:microsecond)
    end
  end
end

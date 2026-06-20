defmodule BibleReader.I18n.CalendarFormat do
  @moduledoc """
  Locale-aware calendar strings for `en` and `de`.

  Elixir's `Calendar.strftime/2` always uses English for `%A`, `%B`, and `%b`.
  Use this module whenever month or weekday names should follow the user's locale.
  """

  @weekdays_en ~w(Monday Tuesday Wednesday Thursday Friday Saturday Sunday)
  @weekdays_de ~w(Montag Dienstag Mittwoch Donnerstag Freitag Samstag Sonntag)

  @months_full_en ~w(January February March April May June July August September October November December)
  @months_full_de ~w(Januar Februar März April Mai Juni Juli August September Oktober November Dezember)

  @months_abbr_en ~w(Jan Feb Mar Apr May Jun Jul Aug Sep Oct Nov Dec)
  @months_abbr_de ~w(Jan Feb Mär Apr Mai Jun Jul Aug Sep Okt Nov Dez)

  @doc """
  Long date for banners and pickers, e.g. `"Monday, Jun 16"` or `"Montag, 16. Juni"`.
  """
  @spec format_long(Date.t(), String.t()) :: String.t()
  def format_long(%Date{} = date, "de") do
    "#{weekday_name(date, "de")}, #{date.day}. #{month_name(date, :full, "de")}"
  end

  def format_long(%Date{} = date, _locale) do
    "#{weekday_name(date, "en")}, #{month_name(date, :abbrev, "en")} #{date.day}"
  end

  @doc """
  Formats a zoned datetime for history lists.

  German uses numeric dates; English uses abbreviated month names via `Calendar.strftime/2`.
  """
  @spec format_datetime(DateTime.t(), String.t()) :: String.t()
  def format_datetime(%DateTime{} = dt, "de") do
    Calendar.strftime(dt, "%d.%m.%Y, %H:%M")
  end

  def format_datetime(%DateTime{} = dt, _locale) do
    Calendar.strftime(dt, "%b %-d, %Y at %-I:%M %p")
  end

  @doc "Full weekday name for `date` in `locale` (`en` or `de`)."
  @spec weekday_name(Date.t(), String.t()) :: String.t()
  def weekday_name(%Date{} = date, locale) do
    weekday_at(date, locale, @weekdays_en, @weekdays_de)
  end

  @doc "Month name for `date`; `:full` or `:abbrev`."
  @spec month_name(Date.t(), :full | :abbrev, String.t()) :: String.t()
  def month_name(%Date{} = date, :full, "de"), do: month_at(date, @months_full_de)
  def month_name(%Date{} = date, :full, _locale), do: month_at(date, @months_full_en)
  def month_name(%Date{} = date, :abbrev, "de"), do: month_at(date, @months_abbr_de)
  def month_name(%Date{} = date, :abbrev, _locale), do: month_at(date, @months_abbr_en)

  defp weekday_at(%Date{} = date, "de", _en, de), do: Enum.at(de, Date.day_of_week(date) - 1)
  defp weekday_at(%Date{} = date, _locale, en, _de), do: Enum.at(en, Date.day_of_week(date) - 1)

  defp month_at(%Date{} = date, months), do: Enum.at(months, date.month - 1)
end

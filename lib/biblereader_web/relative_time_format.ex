defmodule BibleReaderWeb.RelativeTimeFormat do
  @moduledoc """
  Localized display strings for `ReadingPlan.RelativeTime` structured labels.
  """
  use Gettext, backend: BibleReaderWeb.Gettext

  alias BibleReader.ReadingPlan.RelativeTime

  @doc "Formats a structured relative-time label for the given locale."
  @spec format(RelativeTime.label() | nil, String.t()) :: String.t() | nil
  def format(nil, _locale), do: nil

  def format(label, locale) when is_binary(locale) do
    Gettext.with_locale(BibleReaderWeb.Gettext, locale, fn ->
      do_format(label)
    end)
  end

  defp do_format(:today), do: gettext("today")
  defp do_format(:yesterday), do: gettext("yesterday")
  defp do_format({:days, 1}), do: gettext("1d")
  defp do_format({:days, n}), do: gettext("%{count}d", count: n)
  defp do_format({:months, n}), do: gettext("%{count}mo", count: n)
  defp do_format({:years, n}), do: gettext("%{count}y", count: n)
end

defmodule BibleReaderWeb.EffectiveDate do
  @moduledoc """
  Session-backed effective read date for the reading LiveViews.

  Stored in the Plug session under `"effective_read_date"` as an ISO8601 date
  string. `nil` or today means normal logging (`read_at = now`).

  Updates go through `EffectiveDateController` because LiveView cannot mutate
  the Plug session after connect.
  """
  use Gettext, backend: BibleReaderWeb.Gettext
  use BibleReaderWeb, :verified_routes

  import Phoenix.Component
  import Phoenix.LiveView, only: [get_connect_info: 2]
  import Phoenix.LiveView, only: [get_connect_info: 2]

  alias BibleReader.Accounts.User
  alias BibleReader.ReadingPlan.EffectiveDate, as: Domain

  @session_key "effective_read_date"

  @doc "Session key used for the effective read date override."
  def session_key, do: @session_key

  @doc """
  `on_mount` callback: assigns effective-date state for reading pages.
  """
  def on_mount(:assign_effective_date, _params, session, socket) do
    user = current_user(socket, session)
    timezone = user_timezone(user)
    locale = socket.assigns[:locale] || "en"
    return_to = current_path(socket)

    socket =
      socket
      |> assign_effective_date(session, timezone, locale)
      |> assign(:reading_area?, true)
      |> assign(:effective_date_picker_open?, false)
      |> assign(:effective_date_return_to, return_to)

    {:cont, socket}
  end

  @doc """
  Resolves `read_at` for `ReadingPlan.log_chapter_read/3` from socket assigns.
  """
  def read_at_for_logging(%User{} = user, effective_date) do
    case effective_date do
      nil -> nil
      %Date{} = date -> Domain.read_at_for(date, user.timezone || "Etc/UTC")
    end
  end

  @doc "Opens the effective-date picker."
  def open_picker(socket) do
    assign(socket, :effective_date_picker_open?, true)
  end

  @doc "Closes the effective-date picker."
  def close_picker(socket) do
    assign(socket, :effective_date_picker_open?, false)
  end

  defp assign_effective_date(socket, session, timezone, locale) do
    effective_date = parse_session_date(session, timezone)
    options = build_options(timezone, locale, effective_date)

    socket
    |> assign(:effective_date, effective_date)
    |> assign(:effective_date_active?, Domain.active?(effective_date, timezone))
    |> assign(:effective_date_label, banner_label(effective_date, timezone, locale))
    |> assign(:effective_date_options, options)
  end

  defp parse_session_date(session, timezone) do
    case session[@session_key] do
      date_str when is_binary(date_str) ->
        case Domain.validate_string(date_str, timezone) do
          {:ok, date} -> date
          {:error, _} -> nil
        end

      _ ->
        nil
    end
  end

  defp build_options(timezone, locale, effective_date) do
    today = BibleReader.ReadingPlan.RelativeTime.today_in_zone(timezone)

    Domain.selectable_dates(timezone)
    |> Enum.map(fn date ->
      past? = Date.compare(date, today) == :lt

      label =
        if past? do
          Domain.format_long(date, locale)
        else
          gettext("Today (default)")
        end

      selected? =
        cond do
          is_nil(effective_date) and date == today -> true
          effective_date == date -> true
          true -> false
        end

      %{date: date, iso: Date.to_iso8601(date), label: label, past?: past?, selected?: selected?}
    end)
  end

  defp banner_label(%Date{} = date, timezone, locale) do
    if Domain.active?(date, timezone) do
      Domain.format_long(date, locale)
    else
      nil
    end
  end

  defp banner_label(nil, _timezone, _locale), do: nil

  defp current_path(socket) do
    case get_connect_info(socket, :uri) do
      %URI{path: path} when is_binary(path) and path != "" -> path
      _ -> "/read"
    end
  end

  defp current_user(socket, session) do
    socket.assigns[:current_user] || user_from_session(session)
  end

  defp user_from_session(%{"user_token" => token}) when is_binary(token) do
    BibleReader.Accounts.get_user_by_session_token(token)
  end

  defp user_from_session(_), do: nil

  defp user_timezone(%User{timezone: tz}) when is_binary(tz), do: tz
  defp user_timezone(_), do: "Etc/UTC"
end

defmodule BibleReaderWeb.EffectiveDateController do
  @moduledoc """
  Persists the effective read date in the Plug session (reading workflow only).
  """
  use BibleReaderWeb, :controller

  use Gettext, backend: BibleReaderWeb.Gettext

  alias BibleReader.ReadingPlan.EffectiveDate, as: Domain
  alias BibleReaderWeb.EffectiveDate

  def update(conn, params) do
    user = conn.assigns.current_user
    timezone = user.timezone || "Etc/UTC"
    return_to = safe_return_to(params["return_to"])

    case Map.get(params, "date") do
      "today" ->
        conn
        |> delete_session(EffectiveDate.session_key())
        |> redirect(to: return_to)

      date_str when is_binary(date_str) ->
        case Domain.validate_string(date_str, timezone) do
          {:ok, date} ->
            conn
            |> put_session(EffectiveDate.session_key(), Date.to_iso8601(date))
            |> redirect(to: return_to)

          {:error, _} ->
            conn
            |> put_flash(
              :error,
              gettext(
                "That date is not available. Choose today or a day within the last %{days} days.",
                days: Domain.window_days()
              )
            )
            |> redirect(to: return_to)
        end

      _ ->
        conn
        |> put_flash(:error, gettext("That date is not available."))
        |> redirect(to: return_to)
    end
  end

  defp safe_return_to(path) when is_binary(path) do
    if String.starts_with?(path, "/read"), do: path, else: ~p"/read"
  end

  defp safe_return_to(_), do: ~p"/read"
end

defmodule BibleReaderWeb.Plugs.Locale do
  @moduledoc """
  Sets Gettext locale and `conn.assigns.locale` from user, session, or Accept-Language.
  """
  import Plug.Conn

  alias BibleReader.Locale

  @session_key :locale

  def init(opts), do: opts

  def call(conn, _opts) do
    conn = fetch_query_params(conn)
    locale = resolve_locale(conn)
    conn = put_locale(conn, locale)
    put_session(conn, @session_key, locale)
  end

  @doc "Resolves locale for the current connection."
  @spec resolve_locale(Plug.Conn.t()) :: String.t()
  def resolve_locale(conn) do
    cond do
      param_locale(conn) ->
        param_locale(conn)

      user = conn.assigns[:current_user] ->
        Locale.normalize(user.locale)

      session_locale = get_session(conn, @session_key) ->
        Locale.normalize(session_locale)

      true ->
        conn
        |> get_req_header("accept-language")
        |> List.first()
        |> Locale.from_accept_language()
    end
  end

  defp param_locale(conn) do
    case conn.query_params["locale"] do
      locale when is_binary(locale) and locale != "" ->
        normalized = Locale.normalize(locale)
        if Locale.supported?(normalized), do: normalized, else: nil

      _ ->
        nil
    end
  end

  @doc "Sets Gettext locale and assigns on the connection."
  @spec put_locale(Plug.Conn.t(), String.t()) :: Plug.Conn.t()
  def put_locale(conn, locale) do
    locale = Locale.normalize(locale)
    Gettext.put_locale(BibleReaderWeb.Gettext, locale)
    assign(conn, :locale, locale)
  end

  @doc "Session key used for guest locale persistence."
  def session_key, do: @session_key
end

defmodule BibleReaderWeb.PageController do
  use BibleReaderWeb, :controller

  def home(conn, _params) do
    if conn.assigns[:current_user] do
      redirect(conn, to: ~p"/read")
    else
      render(conn, :home, layout: false)
    end
  end

  def privacy(conn, _params) do
    render(conn, :privacy, layout: false)
  end
end

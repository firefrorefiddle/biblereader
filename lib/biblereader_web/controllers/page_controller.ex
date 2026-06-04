defmodule BibleReaderWeb.PageController do
  use BibleReaderWeb, :controller

  def home(conn, _params) do
    redirect(conn, to: ~p"/read")
  end

  def privacy(conn, _params) do
    render(conn, :privacy, layout: false)
  end
end

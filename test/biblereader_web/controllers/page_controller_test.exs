defmodule BibleReaderWeb.PageControllerTest do
  use BibleReaderWeb.ConnCase

  test "GET / redirects to reading home", %{conn: conn} do
    conn = get(conn, ~p"/")
    assert redirected_to(conn) == ~p"/read"
  end
end

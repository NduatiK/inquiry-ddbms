defmodule DdbmsServerWeb.PageController do
  use DdbmsServerWeb, :controller

  def index(conn, _params) do
    render(conn, "index.html")
  end
end

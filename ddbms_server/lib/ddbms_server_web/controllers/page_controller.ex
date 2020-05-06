defmodule DdbmsServerWeb.PageController do
  use DdbmsServerWeb, :controller

  def index(conn, _params) do
    render(conn, "index.html")
  end

  def setup(conn, params) do
    DdbmsServer.DatabaseInterface.setup(params)
    conn
    |> resp(200, "{}")
  end
  def reset(conn, params) do
    DdbmsServer.DatabaseInterface.reset()
    conn
    |> resp(200, "{}")
  end


end

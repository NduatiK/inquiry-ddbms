defmodule DdbmsServerWeb.UserChannel do
  use DdbmsServerWeb, :channel

  def join("live", _payload, socket) do
    {:ok, socket}
  end

  def handle_in("query", %{"script" => script}, socket) do
    script = script |> String.trim()
    with "SELECT" <> _asd <- String.upcase(script) do
      DdbmsServer.DatabaseInterface.select(script)
      {:reply, :ok, socket}
    else
      _ ->
        with "INSERT" <> _asd <- String.upcase(script) do
          DdbmsServer.DatabaseInterface.insert(script)
          {:reply, :ok, socket}
        else
          _ ->
            {:reply, {:error, %{reason: "⧱Only insert and select queries are supported"}}, socket}
        end
    end
  end

  def send_to_channel(data) when is_list(data) do
    data
    |> List.to_string()
    |> String.replace("\r\n", "\n")
    |> send_to_channel()
  end

  def send_to_channel(data) do
    DdbmsServerWeb.Endpoint.broadcast(
      "live",
      "update",
      %{message: data |> String.trim()}
    )
  end
end

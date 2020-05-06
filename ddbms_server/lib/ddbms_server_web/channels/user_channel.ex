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

  @default_opt Keyword.new()

  def send_to_channel(data, opt \\ Keyword.new())

  def send_to_channel(data, opt) when is_list(data) do
    data
    |> List.to_string()
    |> String.replace("\r\n", "\n")
    |> send_to_channel(opt)
  end

  def send_to_channel(data, opt) do
    opt = Keyword.merge(@default_opt, opt)
    label = Keyword.get(opt, :label) || ""
    delay = Keyword.get(opt, :delay) || 0

    Task.async(fn ->
      :timer.sleep(delay)

      DdbmsServerWeb.Endpoint.broadcast(
        "live",
        "update",
        %{message: (label <> data) |> clean_string()}
      )
    end)

    data |> clean_string()
  end

  def clean_string(data) do
    data
    |> String.replace("\r\n", "\n")
    |> String.replace(" | ", "\t")
    |> String.replace("\n ", "\n")
    |> String.replace("\n\n", "\n")
    |> String.replace(" \n", "\n")
    |> String.replace("\n ", "\n")
    |> String.replace("\t  ", "\t")
    |> String.replace("\t ", "\t")
    |> String.replace("  \t", "\t")
    |> String.replace(" \t", "\t")
    |> String.trim_leading()
  end
end

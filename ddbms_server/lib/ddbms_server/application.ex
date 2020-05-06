defmodule DdbmsServer.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  def start(_type, _args) do
    # List all child processes to be supervised
    children = [
      DdbmsServerWeb.Endpoint,
      DdbmsServer.DatabaseInterfaceSupervisor
    ]

    start_dbs()

    opts = [strategy: :one_for_one, name: DdbmsServer.Supervisor]
    Supervisor.start_link(children, opts)
  end

  def start_dbs() do
    # cmd = """
    # docker-compose down & docker-compose up --abort-on-container-exit --force-recreate
    # """
    # cmd = """
    # docker-compose down --force & docker-compose up  --force-recreate
    # """
    # cmd = """
    # docker-compose --no-ansi  down -v  --remove-orphans & docker-compose --no-ansi up --force-recreate  -d
    # """
    cmd = """
    docker-compose --no-ansi up --force-recreate  -V -d
    """

    cmd |> String.to_charlist() |> :os.cmd()
  end

  def config_change(changed, _new, removed) do
    DdbmsServerWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end

defmodule DdbmsServer.DatabaseInterfaceSupervisor do
  use Supervisor

  alias DdbmsServer.DatabaseInterface

  def start_link(_) do
    Supervisor.start_link(__MODULE__, [], name: __MODULE__)
  end

  def init(_) do
    children = [
      worker(DatabaseInterface, [[]])
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end
end

defmodule DdbmsServer.DatabaseInterface do
  use GenServer

  @database_locations %{
    "mysql" => "ddbms_server_mysql_1",
    "postgres" => "ddbms_server_postgres_1",
    "mariadb" => "ddbms_server_mariadb_1"
  }

  def start_link(args) do
    GenServer.start_link(__MODULE__, args, name: __MODULE__)
  end

  def init(init_arg) do
    {:ok, %{}}
  end

  # %{
  #   "conditions" => %{},
  #   "db" => "mariadb",
  #   "fields" => [
  #     %{"fieldType" => "Integer", "name" => "Age"},
  #     ...
  #   ]
  # }

  def handle_cast({:select, script}, state) do
    IO.inspect(state)

    state["partitioning"]
    |> Enum.map(fn part ->
      %{
        "db" => db,
        "fields" => fields
      } = part

      script = script |> String.downcase() |> String.replace("tbl;", "#{db}_tbl;")

      query = script

      localize_cmd(db, query)
      |> String.to_charlist()
      |> :os.cmd()
      |> DdbmsServerWeb.UserChannel.send_to_channel()
    end)

    {:noreply, state}
  end

  def handle_cast({:insert, script}, state) do
    state["partitioning"]
    |> Enum.map(fn part ->
      %{
        "db" => db,
        "fields" => fields
      } = part

      script =
        script
        |> String.downcase()
        |> String.replace("insert into tbl", "insert into #{db}_tbl")

      query = script

      localize_cmd(db, query)
      |> String.to_charlist()
      |> :os.cmd()
      |> DdbmsServerWeb.UserChannel.send_to_channel()
    end)

    {:noreply, state}
  end

  def handle_cast({:setup, parts}, state) do
    IO.inspect(parts)

    parts["partitioning"]
    |> Enum.map(fn part ->
      # %{
      #   "conditions" => %{},
      #   "db" => "mariadb",
      #   "fields" => [
      #     %{"fieldType" => "Integer", "name" => "Age"},
      #     ...
      #   ]
      # }

      %{
        "db" => db,
        "fields" => fields
      } = part

      field_parts =
        fields
        |> Enum.map(fn %{"fieldType" => type, "name" => fieldName} ->
          {fieldName, localize_type(type, db)}
        end)

      query =
        field_parts
        |> Enum.reduce("CREATE TABLE tbl (", fn {field, type}, acc ->
          acc <> ", " <> field <> " " <> type
        end)

      query =
        (query
         |> String.replace_leading("CREATE TABLE tbl (,", "CREATE TABLE #{db}_tbl (")) <> ");"

      cmd = localize_cmd(db, query)

      "📧 → #{db}: #{query}" |> DdbmsServerWeb.UserChannel.send_to_channel()

      resp = cmd |> String.to_charlist() |> :os.cmd()

      DdbmsServerWeb.UserChannel.send_to_channel("#{db} → 📧: #{resp}")
    end)

    {:noreply, parts}
  end

  def handle_cast(:reset, state) do
    DdbmsServer.Application.start_dbs()
    |> IO.inspect()
    |> DdbmsServerWeb.UserChannel.send_to_channel()

    {:noreply, state}
  end

  def setup(params) do
    GenServer.cast(__MODULE__, {:setup, params})
  end

  def select(script) do
    IO.inspect(script)
    GenServer.cast(__MODULE__, {:select, script})
  end

  def insert(script) do
    GenServer.cast(__MODULE__, {:insert, script})
  end

  def reset() do
    GenServer.cast(__MODULE__, :reset)
  end

  def localize_type(type, "postgres") do
    # ddbms_server/deps/ecto_sql/lib/ecto/adapters/tds/connection.ex
    case type do
      "PrimaryKey" ->
        "int PRIMARY KEY"

      "Double" ->
        "float"

      "Integer" ->
        "int"

      "String" ->
        "varchar(255)"
    end
  end

  # Maria uses mysql's commands
  def localize_type(type, "mariadb"),
    do: localize_type(type, "mysql")

  def localize_type(type, "mysql") do
    case type do
      "PrimaryKey" ->
        "INT PRIMARY KEY"

      "Double" ->
        "DOUBLE(10,3)"

      "Integer" ->
        "INT"

      "String" ->
        "VARCHAR(255)"
    end
  end

  # {query}"
  def localize_cmd("postgres" = db, query),
    do:
      "docker exec -i #{@database_locations[db]} psql -t -U postgres  --command \"#{
        query |> String.replace("²", "'")
      }\""

  # {query}"
  def localize_cmd("mariadb" = db, query) do
    sql =
      " CREATE DATABASE IF NOT EXISTS #{db}; USE #{db}; #{query |> String.replace("²", "\\\"")}"

    "docker exec -i  #{@database_locations[db]} bash -c 'echo \"#{sql}\" | #{db}'"
    |> IO.inspect()
  end

  def localize_cmd("mysql" = db, query) do
    sql =
      " CREATE DATABASE IF NOT EXISTS #{db}; USE #{db}; #{query |> String.replace("²", "\\\"")}"

    """
    docker exec -i  #{@database_locations[db]} bash -c 'echo "#{sql}" | #{db}'
    """
    |> IO.inspect()
  end

  # {query}"
end

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
    reg = ~r/^select\s+(.*?)\s+from*/
    IO.inspect(state)

    try do
      reg
      |> Regex.run(script, capture: :all_but_first)
      |> hd()
      |> String.split(",")
      |> Enum.map(&String.trim/1)
      |> IO.inspect()
    rescue
      _ ->
        DdbmsServerWeb.UserChannel.send_to_channel("Invalid query", delay: 50)
        {:noreply, state}
    else
      fields ->
        if fields == ["*"] do
          state["all_fields"]
          |> Enum.map(&Map.get(&1, "name"))
          |> Enum.reduce("", &(&2 <> "\t" <> &1))
          |> String.trim()
          |> (fn x -> ".\n" <> x end).()
          |> DdbmsServerWeb.UserChannel.send_to_channel(delay: 50)
        else
          state["all_fields"]
          # |> IO.inspect()
          |> Enum.map(&Map.get(&1, "name"))
          |> Enum.filter(&Enum.member?(fields, &1))
          # |> IO.inspect()
          |> Enum.reduce("", &(&2 <> "\t" <> &1))
          |> String.trim()
          |> DdbmsServerWeb.UserChannel.send_to_channel(delay: 50)
        end

        fields =
          if fields == ["*"] do
            state["all_fields"]
          else
            fields
          end
          |> Enum.map(&Map.get(&1, "name"))
          |> IO.inspect()

        tasks =
          state["partitioning"]
          |> Enum.map(fn part ->
            %{
              "db" => db,
              "fields" => fields
            } = part

            field_names =
              fields
              |> Enum.map(&Map.get(&1, "name"))
              |> IO.inspect()

            Task.async(fn ->
              script
              |> String.downcase()
              |> String.replace("tbl;", "#{db}_tbl;")
              |> localize_sql(db)
              |> DdbmsServerWeb.UserChannel.send_to_channel(label: "📧 → #{db}: ")
              |> localize_cmd(db)
              |> String.to_charlist()
              |> :os.cmd()
              |> List.to_string()
              |> DdbmsServerWeb.UserChannel.clean_string()
              |> String.trim()
              |> String.split("\n")
              |> Enum.map(&String.split(&1, "\t"))
              |> Enum.map(&Enum.zip(field_names, &1))
            end)
          end)

          # Wait for rows from each db data
          |> Enum.map(fn task ->
            Task.await(task)
          end)
          # Map each row into a map
          |> Enum.map(fn rows ->
            rows
            |> Enum.map(&Map.new/1)
          end)
          # Put all the maps together
          |> Enum.flat_map(& &1)
          # Group them by the id
          |> Enum.group_by(& &1["id"])
          # Merge the groups of maps into a single group of larger maps
          |> Enum.map(fn {_, values} ->
            Enum.reduce(values, %{}, &Map.merge(&2, &1))
          end)
          # For each map (row)
          |> Enum.map(fn map ->
            # Pull the necessary fields,
            Enum.map(fields, fn field -> Map.get(map, field) end)
            |> IO.inspect()
            # Prettify
            |> Enum.join("\t")
            # Serve
            |> DdbmsServerWeb.UserChannel.send_to_channel(delay: 100)
          end)
          |> IO.inspect()

        {:noreply, state}
    end
  end

  def handle_cast({:insert, script}, state) do
    primary_key = state["primary_key"]

    reg = ~r/insert into.*?\((.*?)\) values \((.*?)\);*/

    try do
      reg
      |> Regex.run(script, capture: :all_but_first)
      |> Enum.map(fn x ->
        x
        |> String.split(",")
        |> Enum.map(&String.trim/1)
      end)
      |> IO.inspect()
      |> (fn [fields, values] ->
            if Enum.count(fields) == Enum.count(values) do
              zip =
                Enum.zip(fields, values)
                |> Enum.filter(fn {k, v} -> k != primary_key end)

              {zip ++ [{primary_key, state["id"]}], fields}
            else
              raise(ArgumentError, "Different length field list and values")
            end
          end).()
      |> IO.inspect()
    rescue
      e ->
        IO.inspect(e)
        DdbmsServerWeb.UserChannel.send_to_channel("Invalid query", delay: 50)
        {:noreply, state}
    else
      {fields_values, fields} ->
        db_fields =
          state["all_fields"]
          |> IO.inspect()
          |> Enum.map(&Map.get(&1, "name"))

        cond do
          not MapSet.equal?(MapSet.new(fields), MapSet.new(db_fields -- [primary_key])) ->
            # If some fields are absent
            DdbmsServerWeb.UserChannel.send_to_channel(
              """
              Insert fields do not match the database fields
              Expected: [#{(db_fields -- [primary_key]) |> Enum.join(", ")}]
              Got:      [#{fields |> Enum.join(", ")}]
              """,
              delay: 50
            )

            {:noreply, state}

          true ->
            fields = fields ++ [primary_key]

            state["partitioning"]
            |> Enum.map(fn part ->
              %{
                "db" => db,
                "fields" => db_fields
              } = part

              db_field_names =
                db_fields
                |> Enum.map(&Map.get(&1, "name"))


              {matching_fields, matching_values} =
                fields_values
                |> Enum.filter(fn {x, _} ->
                  x in db_field_names
                end)s
                |> Enum.unzip()

              "insert into tbl (#{Enum.join(matching_fields, ", ")}) values (#{
                Enum.join(matching_values, ", ")
              })"
              |> String.downcase()
              |> String.replace("insert into tbl", "insert into #{db}_tbl")
              |> localize_sql(db)
              |> DdbmsServerWeb.UserChannel.send_to_channel(label: "📧 → #{db}: ")
              |> localize_cmd(db)
              |> String.to_charlist()
              |> :os.cmd()
              |> DdbmsServerWeb.UserChannel.send_to_channel(delay: 100)

              # end)
            end)
        end
    end

    {:noreply, Map.put(state, "id", state["id"] + 1)}
  end

  def handle_cast({:setup, parts}, state) do
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
        query =
        field_parts
        |> Enum.reduce("CREATE TABLE tbl (", fn {field, type}, acc ->
          acc <> ", " <> field <> " " <> type
        end)
        |> (fn x ->
              String.replace_leading(
                x,
                "CREATE TABLE tbl (,",
                "CREATE TABLE #{db}_tbl ("
              )
            end).()
        |> (fn x -> x <> ");" end).()
        |> localize_sql(db)
        |> DdbmsServerWeb.UserChannel.send_to_channel(label: "📧 → #{db}: ")
        |> localize_cmd(db)
        |> String.to_charlist()
        |> :os.cmd()
        |> DdbmsServerWeb.UserChannel.send_to_channel(delay: 100)
    end)

    {:noreply, Map.put(parts, "id", 1)}
  end

  def handle_cast(:reset, state) do
    DdbmsServer.Application.start_dbs()
    |> IO.inspect()
    |> DdbmsServerWeb.UserChannel.send_to_channel()

    {:noreply, state}
  end

  def handle_info(_msg, state) do
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

  def localize_sql(query, "postgres" = db),
    do: query |> String.replace("²", "'")

  def localize_sql(query, "mariadb" = db) do
    "#{query |> String.replace("²", "\\\"")}"
  end

  def localize_sql(query, "mysql" = db) do
    "#{query |> String.replace("²", "\\\"")}"
  end

  def localize_cmd(query, "postgres" = db),
    do:
      "docker exec -i #{@database_locations[db]} psql -t -U postgres  --command \"#{
        query |> String.replace("²", "'")
      }\""

  def localize_cmd(sql, "mariadb" = db) do
    """
    docker exec -i  #{@database_locations[db]} bash -c 'echo " CREATE DATABASE IF NOT EXISTS #{db}; USE #{
      db
    }; #{sql}" | #{db}  -sN'
    """
  end

  def localize_cmd(sql, "mysql" = db) do
    """
    docker exec -i  #{@database_locations[db]} bash -c 'echo " CREATE DATABASE IF NOT EXISTS #{db}; USE #{
      db
    };  #{sql}" | #{db} -sN'
    """
  end
end

defmodule DdbmsServer.DatabaseInterface do
  use GenServer
  @moduledoc """
  Here lies the logic of the distributed system

  This GenServer handles four operations:
    * Setup
    In which the front end provides all the information
    needed to setup all the databasess and stores it in a
    database catalogue in memory

    * Select
    Which uses the catalogue to perform selection queries across vertically and
    horizontally fragmented databases

    * Insert
    Which uses the catalogue to perform insertions queries across vertically and
    horizontally fragmented databases

    *Reset
    Which scraps all the stored database information
  """

  # These are the databases used by the DDBMs
  @database_locations %{
    "mysql" => "ddbms_server_mysql_1",
    "postgres" => "ddbms_server_postgres_1",
    "mariadb" => "ddbms_server_mariadb_1"
  }

  # Setup the GenServer
  def start_link(args) do
    GenServer.start_link(__MODULE__, args, name: __MODULE__)
  end

  def init(init_arg) do
    {:ok, %{}}
  end

  # On select, ...
  def handle_cast({:select, script}, state) do
    reg = ~r/^select\s+(.*?)\s+from*/

    primary_key = state["primary_key"]

    # First try to match the select fields using the regex
    try do
      reg
      |> Regex.run(script, capture: :all_but_first)
      # hd throws an error if there are no matches,
      # otherwise returns the first match eg. "*" or "age, name"
      |> hd()
      # Split this into "*" or ["age", " name"]
      |> String.split(",")
      # Trim this into "*" or ["age", "name"]
      |> Enum.map(&String.trim/1)
      # Inspect the matched fields
      |> IO.inspect()
    rescue
      # If the regex fails, report it the user
      _ ->
        DdbmsServerWeb.UserChannel.send_to_channel("Invalid query", delay: 50)
        {:noreply, state}
    else
      fields ->
        # Print out a row of headers for the result
        if fields == ["*"] do
          state["all_fields"]
          |> Enum.map(&Map.get(&1, "name"))
          |> Enum.reduce("", &(&2 <> "\t" <> &1))
          |> String.trim()
          |> (fn x -> ".\n" <> x end).()
          |> DdbmsServerWeb.UserChannel.send_to_channel(delay: 50)
        else
          state["all_fields"]
          |> Enum.map(&Map.get(&1, "name"))
          |> Enum.filter(&Enum.member?(fields, &1))
          |> Enum.reduce("", &(&2 <> "\t" <> &1))
          |> String.trim()
          |> DdbmsServerWeb.UserChannel.send_to_channel(delay: 50)
        end

        # Discover the requested fields
        requested_fields =
          if fields == ["*"] do
            # if the user asked for all, map this into concrete fields
            state["all_fields"]
            |> Enum.map(&Map.get(&1, "name"))
          else
            # Otherwise only return what they asked for
            fields
          end
          |> IO.inspect()

        tasks =
          state["partitioning"]
          # Filter out databases that do not need to participate
          # No need too query a site if it does not have one
          # of the requested fields
          |> Enum.filter(fn part ->
            %{
              "db" => db,
              "fields" => db_fields
            } = part

            # Get the names of fields in the database
            field_names =
              db_fields
              |> Enum.map(&Map.get(&1, "name"))
              |> IO.inspect()

            # Are any of the fields other than the primary key field being requested?
            # If yes, the `Enum.filter` function keeps it around for the next step
            # Else it leaves it out
            (field_names -- [primary_key])
            |> Enum.any?(fn x ->
              x in requested_fields
            end)
          end)
          # For each of the participating databases, do the following
          |> Enum.map(fn part ->
            %{
              "db" => db,
              "fields" => db_fields
            } = part

            # Get the names of fields in the database
            field_names =
              db_fields
              |> Enum.map(&Map.get(&1, "name"))
              |> IO.inspect()

            # But only request the ones the user asked for
            fields_to_request =
              field_names
              |> Enum.filter(fn x ->
                x in requested_fields
              end)

            # Asynchronously, do the following
            Task.async(fn ->
              # Create a new query for that specific database and for the specific files needed
              "select #{fields_to_request |> Enum.join(", ")} from tbl;"
              |> IO.inspect()
              |> String.downcase()
              # localize the requested query's table name
              |> String.replace("tbl;", "#{db}_tbl;")
              # Map strings into the correct format
              # Postgres likes apostrophes, MariaDB and MySQL like quotes
              # (we escape the quotes for the localize cmd stage)
              |> localize_sql(db)
              # Tell the front end what the new database looks like
              |> DdbmsServerWeb.UserChannel.send_to_channel(label: "📧 → #{db}: ")
              # Wrap the query in a database specific docker exec command
              |> localize_cmd(db)
              # Convert it into a list of characters for Erlang
              |> String.to_charlist()
              # Run the command in the OS
              |> :os.cmd()
              # Convert the result back into a string
              # Remove any leading spaces
              # """
              # 1 | tom | 2
              # 1 | tim | 3
              # """
              |> List.to_string()
              # Clear out result of SQL queries,
              # Postgres uses `|`s to separate values
              # MariaDB and MySQL uses ` \t `s

              |> DdbmsServerWeb.UserChannel.clean_string()
              # Remove any leading spaces
              # """
              # 1 tom 2
              # 1 tim 3
              # """
              |> String.trim()
              # split the multiple rows of data into one string per row
              # [
              #   "1 tom 2",
              #   "1 tim 3"
              # ]
              |> String.split("\n")
              # Split each row into separate values
              # [
              #   ["1", "tom", "2"],
              #   ["1", "tim", "3"]
              # ]
              |> Enum.map(&String.split(&1, "\t"))
              # Zip the field name into the row value
              # [
              #   [{"age", "1"}, {"name", "tom"}, {"id", 2}],
              #   [[{"age", "1"}, {"name", "tom"}, {"id", 3}]
              # ]
              |> Enum.map(&Enum.zip(fields_to_request, &1))
            end)
          end)

          # Wait for each database to finish
          |> Enum.map(fn task ->
            Task.await(task)
          end)

          # Map each row into a map
          # [[
          #   %{"age" => "1", "name"=> "tom", "id" => 2},
          #   %{"age" => "1", "name"=> "tim", "id" => 3},
          # ], ...[]
          # ]
          |> Enum.map(fn rows ->
            rows
            |> Enum.map(&Map.new/1)
          end)

          # Put all the maps together
          # [
          #   %{"age" => "1", "name"=> "tom", "id" => 2},
          #   %{"age" => "1", "name"=> "tim", "id" => 3},
          #   %{"salary" => "1000", "id" => 2},
          #   ...
          # ]
          |> Enum.flat_map(& &1)
          |> IO.inspect()
          # Group them by the id
          # Only useful if a single record was split horizontally
          # Put all the maps together
          # [
          #   [
          #      %{"age" => "1", "name"=> "tom", "id" => 2},
          #      %{"salary" => "1000", "id" => 2}
          #   ]
          #   [
          #      %{"age" => "1", "name"=> "tim", "id" => 3},
          #      %{"salary" => "4000", "id" => 3}
          #   ],
          #   ...
          # ]
          |> Enum.group_by(& &1["id"])
          # Merge the groups of maps into a single group of larger maps
          # [
          #    %{"age" => "1", "name"=> "tom", "id" => 2, "salary" => "1000"}
          #    %{"age" => "1", "name"=> "tim", "id" => 3, "salary" => "4000"}
          #   ...
          # ]
          |> Enum.map(fn {_, values} ->
            Enum.reduce(values, %{}, &Map.merge(&2, &1))
          end)
          # For each map (row)
          |> Enum.map(fn map ->
            # Pull all the fields into a list
            #    ["1", "tom", "2",  "1000"}

            Enum.map(requested_fields, fn field -> Map.get(map, field) end)
            |> IO.inspect()
            # Prettify
            # "1  tom 2 1000"
            |> Enum.join("\t")
            # Serve it to the front end
            |> DdbmsServerWeb.UserChannel.send_to_channel(delay: 100)
          end)
          |> IO.inspect()

        {:noreply, state}
    end
  end

  # Look at select for more comments
  def handle_cast({:insert, script}, state) do
    # Assume a script
    #   insert into tbl (age, name) values (1,"tom");

    primary_key = state["primary_key"]
    IO.inspect(state)

    reg = ~r/insert into.*?\((.*?)\) values \((.*?)\);*/

    # First try to match the select fields using the regex
    try do
      reg
      # Should capture  ["age, name"] and ["1,\"tom\""]
      |> Regex.run(script, capture: :all_but_first)
      # Turn this into ["age, "name"] and ["1", "\"tom\""]
      |> Enum.map(fn x ->
        x
        |> String.split(",")
        |> Enum.map(&String.trim/1)
      end)
      |> IO.inspect()
      # Turn this into [{"age, "1"}, {"name", "\"tom\""}, {"id", "10"}]
      # Where 10 is retrieved from the auto increment variable state["id"]}
      #
      # Fail if the number of fields is not equal to the number of values
      # imagine a query
      #     insert into tbl (age, name) values (1,"tom", 3);
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

        # Confirm that we are inserting all columns
        cond do
          not MapSet.equal?(MapSet.new(fields), MapSet.new(db_fields -- [primary_key])) ->
            # The above translates into,
            # if the set of fields provided by the user are not equal
            # to the set of database field other than the primary_key field
            # Tell the front end
            # and stop

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
            # Else
            fields = fields ++ [primary_key]

            state["partitioning"]
            # Filter out databases that do not need to participate
            # Perhaps a horizontal fragmentation condition was set
            # that precludes it from the insert
            |> Enum.filter(fn part ->
              %{
                "db" => db,
                "conditions" => conditions,
                "fields" => db_fields
              } = part

              db_field_names =
                db_fields
                |> Enum.map(&Map.get(&1, "name"))

              # If it meets the conditions for the insert keep it else discard
              meets_conditions(conditions, fields_values)
            end)
            |> Enum.map(fn part ->
              %{
                "db" => db,
                "conditions" => conditions,
                "fields" => db_fields
              } = part

              db_field_names =
                db_fields
                |> Enum.map(&Map.get(&1, "name"))

              # Only insert the fields present in that fragment
              # Vertical fragmentation may prevent a field from
              # being inserted into a fragment
              # Eg for a given db A we will get
              # [{"name", "id"}, {"\"tom\"", "10"}
              # (age was dropped)
              {matching_fields, matching_values} =
                fields_values
                # Filter down to the matching fields and split the values and fields
                |> Enum.filter(fn {field_name, field_value} ->
                  field_name in db_field_names
                end)
                |> Enum.unzip()

              # Build the new query for db A
              # insert into tbl (name, id) values ("tom", 10);
              "insert into tbl (#{Enum.join(matching_fields, ", ")}) values (#{
                Enum.join(matching_values, ", ")
              });"
              # Look at comments in select
              |> String.downcase()
              |> String.replace("insert into tbl", "insert into #{db}_tbl")
              |> localize_sql(db)
              |> DdbmsServerWeb.UserChannel.send_to_channel(label: "📧 → #{db}: ")
              |> localize_cmd(db)
              |> String.to_charlist()
              |> :os.cmd()
              |> DdbmsServerWeb.UserChannel.send_to_channel(delay: 100)
            end)
        end
    end

    {:noreply, Map.put(state, "id", state["id"] + 1)}
  end

  def handle_cast({:setup, parts}, state) do
    # When the user provides partition information,
    # do the following for each database
    parts["partitioning"]
    |> Enum.map(fn part ->
      %{
        "db" => db,
        "fields" => fields
      } = part

      # Localize the frontend types to local types
      # PrimaryKey -> int PRIMARY KEY
      # Look at the definition of localize_type\2 at bottom of the page
      field_parts =
        fields
        |> Enum.map(fn %{"fieldType" => type, "name" => fieldName} ->
          {fieldName, localize_type(type, db)}
        end)

      # Create a CREATE TABLE query given the local types and names
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
        # Once again look at select
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
    # Just restart the containers
    DdbmsServer.Application.start_dbs()
    |> IO.inspect()
    |> DdbmsServerWeb.UserChannel.send_to_channel()

    {:noreply, state}
  end

  def handle_info(_msg, state) do
    {:noreply, state}
  end

  def setup(params) do
    IO.inspect(params)
    GenServer.cast(__MODULE__, {:setup, params})
  end

  def select(script) do
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

  # if there is a condition, then test it out
  def meets_conditions(%{"field" => field} = conditions, fields_values) do
    fields_values
    |> Enum.any?(fn {field_name, field_value} ->
      field == field_name && test_condition(conditions, field_name, field_value)
    end)
    |> IO.inspect()
  end

  # if there are no conditions, then they are all met
  def meets_conditions(%{} = conditions, fields_values) do
    true
  end

  # if the condition field is the same as the field being tested do this
  def test_condition(%{"field" => field} = condition_params, field, value) do
    %{"condition" => condition, "value" => condition_value} = condition_params

    # Map the value of the field into a float
    # or try to
    # or try to
    try do
      try do
        IO.inspect(value)
        String.to_float(value)
      rescue
        _ ->
          String.to_integer(value) + 0.0
      else
        value ->
          value
      end
    rescue
      _ ->
        false
    else
      # If it works, convert the textual condition into a real value comparison
      value ->
        cond do
          String.contains?(condition, ">") && value > condition_value ->
            true

          String.contains?(condition, "<") && value < condition_value ->
            true

          # This deals with any >= or <= conditions that did not meet the > or < part
          String.contains?(condition, "=") && value == condition_value ->
            true

          true ->
            false
        end
    end
  end

  # if the condition field is not the same
  # trivially pass the condition
  def test_condition(_, _, _) do
    true
  end
end

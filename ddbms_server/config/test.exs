use Mix.Config

# We don't run a server during test. If one is required,
# you can enable the server option below.
config :ddbms_server, DdbmsServerWeb.Endpoint,
  http: [port: 4002],
  server: false

# Print only warnings and errors during test
config :logger, level: :warn

# Configure your database
config :ddbms_server, DdbmsServer.Repo,
  username: "postgres",
  password: "postgres",
  database: "ddbms_server_test",
  hostname: "localhost",
  pool: Ecto.Adapters.SQL.Sandbox

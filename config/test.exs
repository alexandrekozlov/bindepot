import Config

config :bindepot,
  cache_dir: System.get_env("BINDEPOT_CACHE_DIR", Path.join(System.fetch_env!("HOME"), ".bindepot/cache")),
  data_dir: System.get_env("BINDEPOT_DATA_DIR", Path.join(System.fetch_env!("HOME"), ".bindepot/data"))

# Configure your database
#
# The MIX_TEST_PARTITION environment variable can be used
# to provide built-in test partitioning in CI environment.
# Run `mix help test` for more information.
config :bindepot, Bindepot.Repo,
  username: "postgres",
  password: "postgres",
  hostname: "localhost",
  database: "bindepot_test#{System.get_env("MIX_TEST_PARTITION")}",
  pool: Ecto.Adapters.SQL.Sandbox,
  pool_size: System.schedulers_online() * 2

# We don't run a server during test. If one is required,
# you can enable the server option below.
config :bindepot, BindepotWeb.Endpoint,
  http: [ip: {127, 0, 0, 1}, port: 4002],
  secret_key_base: "FP4B2eZ68O8jjynI2t0oFH8gC9IUVVPlVS7QonGKM09ET70PauOo7+g/QW3QlGfa",
  server: false

# Print only warnings and errors during test
config :logger, level: :warning

# Initialize plugs at runtime for faster test compilation
config :phoenix, :plug_init_mode, :runtime

# Enable helpful, but potentially expensive runtime checks
config :phoenix_live_view,
  enable_expensive_runtime_checks: true

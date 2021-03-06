use Mix.Config

# We don't run a server during test. If one is required,
# you can enable the server option below.
config :simple_mongo_app, SimpleMongoAppWeb.Endpoint,
  http: [port: 4001],
  server: false

config :simple_mongo_app, timings: {1, 2, 3}

# Print only warnings and errors during test
config :logger, level: :warn

use Mix.Config

# Set the log level
#
# The order from most information to least:
#
#   :debug
#   :info
#   :warn
#
config :logger, level: :info

config :artemis_log, ArtemisLog.Repo,
  username: System.get_env("ARTEMIS_LOG_POSTGRES_USER"),
  password: System.get_env("ARTEMIS_LOG_POSTGRES_PASS"),
  database: System.get_env("ARTEMIS_LOG_POSTGRES_DB"),
  hostname: System.get_env("ARTEMIS_LOG_POSTGRES_HOST"),
  port: System.get_env("ARTEMIS_LOG_POSTGRES_PORT"),
  ssl: Enum.member?(["true", "\"true\""], System.get_env("ARTEMIS_LOG_POSTGRES_SSL_ENABLED")),
  pool_size: 10

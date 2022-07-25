import Config

config :url_failover,
  check_interval: :timer.seconds(10),
  check_timeout: :timer.seconds(10)

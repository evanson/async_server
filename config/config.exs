use Mix.Config

config :async_server,
  port: 7575,
  redis_queue: "requests"
  
config :exredis,
  host: "127.0.0.1",
  port: 6379,
  password: "",
  db: 5,
  reconnect: :no_reconnect,
  max_queue: :infinity

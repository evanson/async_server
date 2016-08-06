defmodule AsyncServer.RedisPool.Supervisor do
  use Supervisor
  require Logger

  def start_link do
    Supervisor.start_link(__MODULE__, [])
  end

  def init(_) do
    Logger.info "Starting redis pool supervisor"
    
    connector_pool_opts = [
      name: {:local, :redis_connection_pool},
      worker_module: Exredis,
      size: 10,
      max_overflow: 10
    ]

    children = [
      :poolboy.child_spec(:redis_connection_pool, connector_pool_opts)
    ]
    
    supervise(children, strategy: :one_for_one, max_restarts: 1000000,
              max_seconds: 3600)
  end
end

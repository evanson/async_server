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
      worker_module: AsyncServer.RedisPool.Worker,
      size: 10,
      max_overflow: 0
    ]

    children = [
      :poolboy.child_spec(:redis_connection_pool, connector_pool_opts, [])
    ]
    
    supervise(children, strategy: :one_for_one)
  end
end

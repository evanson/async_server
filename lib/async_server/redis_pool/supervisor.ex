defmodule AsyncServer.RedisPool.Supervisor do
  use Supervisor
  require Logger

  def start_link do
    Supervisor.start_link(__MODULE__, [])
  end

  def init(_) do
    Logger.info "Starting redis pool supervisor"
    pool_opts = [
      name: {:local, :redis_producer_pool},
      worker_module: AsyncServer.RedisPool.Producer,
      size: 10,
      max_overflow: 10
    ]

    children = [
      :poolboy.child_spec(:redis_producer_pool, pool_opts)
    ]
    supervise(children, strategy: :one_for_one)
  end
end

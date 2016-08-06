defmodule AsyncServer.RedisPool.Producer do
  require Logger
  
  def queue_message(conn, msg) do
    queue = Application.get_env(:async_server, :redis_queue)
    Exredis.query(conn, ["RPUSH", queue, msg])
    Logger.info "Message #{msg} pushed to redis list #{queue}"
  end
end

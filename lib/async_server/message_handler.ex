defmodule AsyncServer.MessageHandler do
  alias AsyncServer.RedisPool.Worker, as: RedisWorker
  require Logger
  
  @derive [Poison.Encoder]
  defstruct [:client_ip, :message]
  
  def process_message(msg, socket) do
    {:ok, {ip_addr, _port}} = :inet.peername(socket)
    client_ip = to_string(:inet.ntoa(ip_addr))
    tagged_msg = %__MODULE__{client_ip: client_ip, message: msg}
    msg = Poison.encode!(tagged_msg)
    queue_message(msg)
  end

  defp queue_message(msg) do
    :poolboy.transaction(:redis_connection_pool, fn(worker) ->
      RedisWorker.queue_message(worker, msg)
    end, :infinity)
  end  
end

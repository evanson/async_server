defmodule AsyncServer.MessageHandler do
  alias AsyncServer.RedisPool.Worker, as: RedisWorker
  require Logger
  
  @derive [Poison.Encoder]
  defstruct [:client_ip, :message]
  
  def process_message(msg, socket) do
    {:ok, {ip_addr, _port}} = :inet.peername(socket)
    tagged_msg = %__MODULE__{client_ip: ip_addr_to_string(ip_addr), message: msg}
    msg = Poison.encode!(tagged_msg)
    queue_message(msg)
  end

  defp queue_message(msg) do
    :poolboy.transaction(:redis_connection_pool, fn(worker) ->
      RedisWorker.queue_message(worker, msg)
    end, :infinity)
  end

  defp ip_addr_to_string({octet_a, octet_b, octet_c, octet_d}) do
    to_string(octet_a) <> "." <> to_string(octet_b) <> "." <>
      to_string(octet_c) <> "." <> to_string(octet_d)
  end
end

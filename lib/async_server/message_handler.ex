defmodule AsyncServer.MessageHandler do
  @derive [Poison.Encoder]
  defstruct [:client_ip, :message]

  require Logger
  alias AsyncServer.RedisPool.Producer, as: RedisSender
  
  def process_message(msg, socket) do
    {:ok, {ip_addr, _port}} = :inet.peername(socket)
    tagged_msg = %__MODULE__{client_ip: ip_addr_to_string(ip_addr), message: msg}
    msg = Poison.encode!(tagged_msg)
    queue_message(msg)
  end

  defp queue_message(msg) do
    Logger.info "Queueing message #{msg}"
    :poolboy.transaction(:redis_connection_pool, fn(worker) ->
      RedisSender.queue_message(worker, msg)
    end)
  end

  defp ip_addr_to_string({octet_a, octet_b, octet_c, octet_d}) do
    to_string(octet_a) <> "." <> to_string(octet_b) <> "." <>
      to_string(octet_c) <> "." <> to_string(octet_d)
  end
end

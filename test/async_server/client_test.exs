defmodule AsyncServerClientTest do
  use ExUnit.Case

  setup do
    opts = [:binary, packet: 0, active: false]
    {:ok, socket} = :gen_tcp.connect('localhost', 7575, opts)
    {:ok, socket: socket}
  end

  test "server interaction", %{socket: socket} do
    # config is setup such that requests and responses queues are the same
    # messages sent are therefore just routed back
    assert send_and_recv(socket, "hello server!") == "hello server!"

    ip = ip_addr(socket)
    ip = AsyncServer.Util.ip_addr_to_string(ip)    
    assert  ip == "127.0.0.1"
    resp = AsyncServer.ClientRegistry.lookup(:client_registry, ip)
    assert  resp != :error
    assert elem(resp, 0) == :ok

    assert AsyncServer.ClientRegistry.register_client(:client_registry, self, socket) == :already_registered
  end

  test "pushing response messages to redis will deliver to client", %{socket: socket} do    
    {:ok, redis_conn} = Exredis.start_link
    message = "{\"client_ip\": \"127.0.0.1\", \"message\": \"message to redis\"}"

    Exredis.query(redis_conn, ["RPUSH", "requests", message])
    assert recv_message(socket) == "message to redis"
  end

  defp send_and_recv(socket, msg) do
    :ok = :gen_tcp.send(socket, <<byte_size(msg)::size(16)>> <> msg)
    recv_message(socket)
  end

  defp recv_message(socket) do
    msg =
      with {:ok, <<msg_len::size(16)>>} <- :gen_tcp.recv(socket, 2), 
           {:ok, <<msg::binary-size(msg_len)>>} <- :gen_tcp.recv(socket, msg_len),
           do: msg
    msg
  end

  defp ip_addr(socket) do
    {:ok, {ip, _port}} = :inet.peername(socket)
    ip
  end
end

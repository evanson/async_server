defmodule AsyncServer.Client do
  require Logger

  @doc """
  Reads from socket and spawns a new task to handle the message.
  """
  def consume(socket) do
    socket
    |> read_message
    |> handle_message(socket)
    consume(socket)
  end

  @doc """
  Reads first 2 bytes, the message length, then reads next <message length> bytes
  """
  defp read_message(socket) do
    msg =
      with {:ok, <<msg_len::size(16)>>} <- :gen_tcp.recv(socket, 2),
           {:ok, <<msg::binary-size(msg_len)>>} <- :gen_tcp.recv(socket, msg_len),
           do: {:ok, msg}
    msg
  end

  defp handle_message({:ok, msg}, socket) do
    Logger.info "Got message #{msg}"
    Task.Supervisor.start_child(AsyncServer.MessageHandlerSupervisor,
                                AsyncServer.MessageHandler, :process_message, [msg, socket])
  end

  defp handle_message({:error, :closed}, _socket) do
    Logger.info "Lost connection to client"
    exit(:shutdown)
  end

  defp handle_message({:error, reason}, _socket) do
    Logger.info "Error reading from client: #{reason}"
  end
end

defmodule AsyncServer.Acceptor do
  require Logger

  def accept(port) do
    Logger.info "Starting acceptor"
    {:ok, socket} = :gen_tcp.listen(port,
                                    [:binary, packet: 0, active: false, reuseaddr: true])
    Logger.info "Accepting connections on port #{port}"
    loop_acceptor(socket)
  end

  defp loop_acceptor(socket) do
    {:ok, client} = :gen_tcp.accept(socket)
    Logger.info "Got new client"
    {:ok, pid} = Task.Supervisor.start_child(AsyncServer.ClientSupervisor,
                                             AsyncServer.Client, :init, [client])
    :ok = :gen_tcp.controlling_process(client, pid)
    loop_acceptor(socket)
  end
end

defmodule AsyncServer.ClientRegistry do
  use GenServer
  require Logger

  def start_link(name) do
    GenServer.start_link(__MODULE__, name, name: name)
  end

  def init(table) do
    {:ok, {nil, table, %{}}}
  end

  def register_client(registry, pid, socket) do
    GenServer.call(registry, {:register_client, pid, socket})
  end

  def lookup(registry, ip_addr) do
    case :ets.lookup(registry, ip_addr) do
      [{^ip_addr, sock, pid}] -> {:ok, sock}
      [] -> :error
    end
  end

  def handle_call({:register_client, pid, socket}, _from, {clients, table, pids}) do
    {:ok, {ip_addr, _}} = :inet.peername(socket)
    client_ip = to_string(:inet.ntoa(ip_addr))

    case lookup(clients, client_ip) do
      {:ok, _sock} ->
        {:reply, :already_registered, {clients, table, pids}}
      :error ->
        Process.monitor(pid)
        :ets.insert(clients, {client_ip, socket, pid})
        {:reply, :ok, {clients, table, Map.put(pids, pid, client_ip)}}
    end
  end

  def handle_info({:DOWN, _ref, :process, pid, _reason}, {clients, table, pids}) do
    {client_ip, pids} = Map.pop(pids, pid)
    :ets.delete(clients, client_ip)
    Logger.info "Removed client #{client_ip} from registry"
    {:noreply, {clients, table, pids}}
  end

  def handle_info({:"ETS-TRANSFER", tableid, from, table}, {nil, table, pids}) do
    clients = :ets.tab2list(tableid)
    Enum.each(clients, fn {ip, sock, pid} ->
      if Process.alive?(pid) do
        Process.monitor(pid)
      else
        :ets.delete(tableid, ip)
      end
    end)
    connected_clients = :ets.tab2list(tableid)
    pids = Enum.reduce(connected_clients, pids, fn({ip, sock, pid}, acc) ->
      Map.put(acc, pid, ip)
    end)
    {:noreply, {tableid, table, pids}}
  end
end

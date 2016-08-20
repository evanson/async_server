defmodule AsyncServer.ClientRegistry do
  use GenServer
  require Logger
  import AsyncServer.Util, only: [ip_addr_to_string: 1]

  def start_link(name) do
    GenServer.start_link(__MODULE__, name, name: name)
  end

  def init(table) do
    clients = :ets.new(table, [:named_table, :set, read_concurrency: true])
    {:ok, {clients, %{}}}
  end

  def register_client(registry, pid, socket) do
    GenServer.call(registry, {:register_client, pid, socket})
  end

  def lookup(registry, ip_addr) do
    case :ets.lookup(registry, ip_addr) do
      [{^ip_addr, sock}] -> {:ok, sock}
      [] -> :error
    end
  end

  def handle_call({:register_client, pid, socket}, _from, {clients, pids}) do
    {:ok, {ip_addr, _}} = :inet.peername(socket)
    client_ip = ip_addr_to_string(ip_addr)

    case lookup(clients, client_ip) do
      {:ok, _sock} ->
        {:reply, :already_registered, {clients, pids}}
      :error ->
        Process.monitor(pid)
        :ets.insert(clients, {client_ip, socket})
        {:reply, :ok, {clients, Map.put(pids, pid, client_ip)}}
    end
  end

  def handle_info({:DOWN, _ref, :process, pid, _reason}, {clients, pids}) do
    {client_ip, pids} = Map.pop(pids, pid)
    :ets.delete(clients, client_ip)
    {:noreply, {clients, pids}}
  end
end

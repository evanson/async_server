defmodule AsyncServer.ETSManager do
  use GenServer
  require Logger
  import Supervisor.Spec

  def start_link(name) do
    GenServer.start_link(__MODULE__, name, name: :ets_manager)
  end

  def init(table) do
    tableid = :ets.new(table, [:named_table, :set, {:heir, self(), table}, read_concurrency: true,])
    Process.send_after(self, :start_handler, 100)
    {:ok, tableid}
  end
  
  def handle_info(:start_handler, tableid) do
    handler = worker(AsyncServer.ClientRegistry, [:client_registry])
    case Supervisor.start_child(AsyncServer.Supervisor, handler) do
      {:ok, pid} ->
        :ets.give_away(tableid, pid, tableid)
      {:error, reason} ->
        Logger.info "Could not start ets handler for table #{tableid}"   
    end
    {:noreply, tableid}
  end
  
  def handle_info({:"ETS-TRANSFER", tableid, from, table}, tableid) do
    Logger.info "ets handler down.. taking table ownership"
    pid  = wait_for_handler(table)
    :ets.give_away(table, pid, table)
    Logger.info "ets table given to new handler"
    {:noreply, tableid}
  end

  defp wait_for_handler(table) do
    case Process.whereis(table) do
      nil ->
        :timer.sleep(1)
        wait_for_handler(table)
      pid ->
        pid
    end
  end
end

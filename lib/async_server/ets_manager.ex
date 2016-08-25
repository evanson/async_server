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
    give_away(tableid)
    {:noreply, tableid}
  end

  defp give_away(table) do
    case wait_for_handler(table, :infinity) do
      :timeout ->
        {:error, :timeout}
      pid when :erlang.is_pid(pid) ->
        :ets.give_away(table, pid, table)
        Logger.info "ets ownership given to new ets handler"
        {:ok, pid}
      {:error, reason} ->
        Logger.info "Could not wait for ets handler for table #{table}"
        {:error, reason}
    end
  end

  defp wait_for_handler(table, timeout) do
    case :erlang.whereis(table) do
      :undefined ->
        case timeout do
          :infinity ->
            :timer.sleep(10)
            wait_for_handler(table, timeout)
          time when time > 0 ->
            :timer.sleep(10)
            wait_for_handler(table, time - 10)
          _ ->
            :timeout
        end
      pid ->
        pid
    end
  end
end

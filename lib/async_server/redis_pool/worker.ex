defmodule AsyncServer.RedisPool.Worker do
  use GenServer
  require Logger

  @reconnect_after 5000

  def start_link(_) do
    GenServer.start_link(__MODULE__, nil)
  end

  def queue_message(worker, msg) do
    GenServer.call(worker, {:queue_message, msg})
  end

  def init(_) do
    Process.flag(:trap_exit, true)
    state = %{redis_conn: nil, status: :disconnected, reconnect_timer: nil}
    {:ok, connect(state)}
  end

  def handle_call({:queue_message, msg}, _, %{redis_conn: nil} = state) do
    Logger.info "Redis down, buffering message #{msg}"
    {:reply, :ok, state}
  end
  
  def handle_call({:queue_message, msg}, _, %{redis_conn: redis_conn} = state) do
    queue = Application.get_env(:async_server, :redis_queue)
    case Process.alive?(redis_conn) do
      true ->
        Exredis.query(redis_conn, ["RPUSH", queue, msg])
        Logger.info "Message #{msg} pushed to redis list #{queue}"
      false ->
        Logger.info "Redis down, buffering message #{msg}"
    end
    {:reply, :ok, state}
  end

  def handle_info(:connect, state) do
    {:noreply, connect(%{state | reconnect_timer: nil})}
  end

  def handle_info({:EXIT, redis_conn, _},%{redis_conn: redis_conn} = state) do
    Logger.info "Connection to redis lost"
    {:noreply, connect(state)}
  end

  def handle_info({:EXIT, _, _reason}, state) do
    {:noreply, state}
  end

  defp connect(state) do
    case Exredis.start_link do
      {:ok, redis_conn} ->
        Logger.info "Connection to redis established"
        %{state | redis_conn: redis_conn, status: :connected}
      {:error, _} ->
        connection_failed(state)
    end
  end

  defp connection_failed(state)  do
    Logger.error "Connection to redis failed. Attempting reconnect..."
    %{state | redis_conn: nil,
      reconnect_timer: schedule_reconnect(state),
      status: :disconnected}
  end

  defp schedule_reconnect(state) do
    if state.reconnect_timer, do: Process.cancel_timer(state.reconnect_timer)
    Process.send_after(self, :connect, @reconnect_after)
  end
  
end

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
    queue = Application.get_env(:async_server, :redis_queue)
    state = %{redis_conn: nil, status: :disconnected, reconnect_timer: nil,
              buffer: :queue.new(), redis_queue: queue}
    {:ok, connect(state)}
  end

  def handle_call({:queue_message, msg}, _, %{redis_conn: nil} = state) do
    Logger.info "Redis down, buffering message #{msg}"
    buffer = :queue.in(msg, state.buffer)
    {:reply, :ok, %{state | buffer: buffer}}
  end
  
  def handle_call({:queue_message, msg}, _, %{redis_conn: redis_conn} = state) do
    case Process.alive?(redis_conn) do
      true ->
        Exredis.query(redis_conn, ["RPUSH", state.redis_queue, msg])
        Logger.info "Message #{msg} pushed to redis list #{state.redis_queue}"
        {:reply, :ok, state}
      false ->
        Logger.info "Redis down, buffering message #{msg}"
        buffer = :queue.in(msg, state.buffer)
        {:reply, :ok, %{state | buffer: buffer}}
    end
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
        state = %{state | redis_conn: redis_conn, status: :connected}
        flush_buffer(state)
      {:error, _} ->
        Logger.error "Connection to redis failed. Attempting reconnect..."
        %{state | redis_conn: nil,
          reconnect_timer: schedule_reconnect(state),
          status: :disconnected}
    end
  end

  defp schedule_reconnect(state) do
    if state.reconnect_timer, do: Process.cancel_timer(state.reconnect_timer)
    Process.send_after(self, :connect, @reconnect_after)
  end

  defp flush_buffer(%{redis_conn: redis_conn, buffer: buffer, redis_queue: queue}=state) do
    case :queue.out(buffer) do
      {{:value, msg}, new_buffer} ->
        if Process.alive?(redis_conn) do
          Exredis.query(redis_conn, ["RPUSH", state.redis_queue, msg])
          Logger.info "Message #{msg} (from buffer) pushed to redis list #{state.redis_queue}"
          flush_buffer(%{state | buffer: new_buffer})
        else
          state
        end
      {:empty, _} ->
        state
    end
  end
end

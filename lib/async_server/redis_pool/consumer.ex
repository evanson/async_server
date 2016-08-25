defmodule AsyncServer.RedisPool.Consumer do
  use GenServer
  require Logger

  @reconnect_after 5000

  def start_link(_) do
    GenServer.start_link(__MODULE__, nil)
  end

  def init(_) do
    Process.flag(:trap_exit, true)
    queue = Application.get_env(:async_server, :redis_response_queue)
    processing_queue = Application.get_env(:async_server, :redis_processing_queue)
    state = %{redis_conn: nil, status: :disconnected, reconnect_timer: nil,
              redis_queue: queue, processing_queue: processing_queue}
    {:ok, connect(state)}
  end

  def handle_info(:consume, %{redis_conn: nil}=state) do
    {:noreply, state}
  end

  def handle_info(:consume, %{redis_conn: redis_conn}=state) do
    if Process.alive?(redis_conn) do
      case Exredis.query(redis_conn, ["RPOPLPUSH", state.redis_queue, state.processing_queue]) do
        :undefined -> # No message
          nil
        msg ->
          case process_response(msg) do
            {:ok, :sent} ->
              Exredis.query(redis_conn, ["LREM", state.processing_queue, "-1", msg])
            {:error, :requeue} ->
              Exredis.query(redis_conn, ["RPUSH", state.redis_queue, msg])
              Exredis.query(redis_conn, ["LREM", state.processing_queue, "-1", msg])
            {:error, reason} ->
              Logger.info "Error #{reason}"
          end   
      end
    end
    Process.send_after(self, :consume, 1)
    {:noreply, state}
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

  defp process_response(msg) do
    case Poison.decode(msg, as: %AsyncServer.MessageHandler{}) do
      {:ok, message} ->
        client_ip = message.client_ip
        response = message.message
        case AsyncServer.ClientRegistry.lookup(:client_registry, client_ip) do
          {:ok, sock} ->
            Logger.info "Sending response #{response} to client #{client_ip}"
            :gen_tcp.send(sock, <<byte_size(response)::size(16)>> <> response)
            {:ok, :sent}
          :error ->
            Logger.info "Client #{client_ip} disconnected, requeueing #{response}"
            {:error, :requeue}
        end
      {:error, _} ->
        Logger.info "Error decoding message #{msg}"
        {:error, :invalid_data}
    end
  end

  defp connect(state) do
    case Exredis.start_link do
      {:ok, redis_conn} ->
        Logger.info "Connection to redis established"
        Process.send_after(self, :consume, 100)
        %{state | redis_conn: redis_conn, status: :connected}
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
end

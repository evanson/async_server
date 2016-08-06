defmodule AsyncServer.RedisPool.Producer do
  use GenServer
  require Logger

  def start_link(state) do
    GenServer.start_link(__MODULE__, state, [])
  end

  def init(state) do
    {:ok, state}
  end

  def queue_message(producer, msg) do
    GenServer.cast(producer, {:queue_message, msg})
  end

  def handle_cast({:queue_message, msg}, state) do
    Logger.info "Sending message #{msg} to redis"
    {:noreply, state}
  end
end

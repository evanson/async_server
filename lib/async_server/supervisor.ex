defmodule AsyncServer.Supervisor do
  use Supervisor

  def start_link do
    Supervisor.start_link(__MODULE__, [])
  end

  def init(_) do
    children = [
      worker(Task, [AsyncServer.Acceptor, :accept, [Application.get_env(:async_server, :port)]]),
      supervisor(Task.Supervisor, [[name: AsyncServer.TaskSupervisor]], id: :task_sup_1),
      supervisor(Task.Supervisor, [[name: AsyncServer.MessageHandlerSupervisor,
                                    restart: :transient]], id: :task_sup_2),
      supervisor(AsyncServer.RedisPool.Supervisor, [])
    ]
    # A crash of the listener process takes down everything
    supervise(children, strategy: :rest_for_one)
  end
end

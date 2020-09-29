defmodule Exampple.Router.Task do
  @moduledoc """
  Starts the handling of the stanza. This task is launched
  by `Exampple.Router.Task.Monitor` and it is using the
  `Exampple.Router` to route the stanza to the correct controller.
  """
  alias Exampple.Router.Conn

  @task_sup Exampple.Router.Task.Supervisor

  @doc """
  Starts the task under the `Exampple.Router.Task.Supervisor`.
  """
  def start(xmlel, domain, otp_app) do
    args = [xmlel, domain, otp_app]
    opts = [restart: :temporary]

    Task.Supervisor.start_child(@task_sup, __MODULE__, :run, args, opts)
  end

  @doc """
  Stops the task using the supervisor to perform this action correctly.
  """
  def stop(pid) do
    Task.Supervisor.terminate_child(@task_sup, pid)
  end

  @doc """
  The code which is being ran by the task.
  """
  def run(xmlel, domain, otp_app) do
    module = Application.get_env(otp_app, :router)
    conn = Conn.new(xmlel, domain)
    query = xmlel.children
    module.route(conn, query)
  end
end

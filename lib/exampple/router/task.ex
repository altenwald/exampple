defmodule Exampple.Router.Task do
  alias Exampple.Router.Conn

  @task_sup Exampple.Router.Task.Supervisor

  def start(xmlel, domain, otp_app) do
    args = [xmlel, domain, otp_app]
    opts = [restart: :temporary]

    Task.Supervisor.start_child(@task_sup, __MODULE__, :run, args, opts)
  end

  def stop(pid) do
    Task.Supervisor.terminate_child(@task_sup, pid)
  end

  def run(xmlel, domain, otp_app) do
    module = Application.get_env(otp_app, :router)
    conn = Conn.new(xmlel, domain)
    query = xmlel.children
    module.route(conn, query)
  end
end

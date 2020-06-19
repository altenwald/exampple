defmodule Exampple.Router.Task do
  alias Exampple.Router.Conn

  @task_sup Exampple.Router.Task.Supervisor

  def start(xmlel, domain, otp_app) do
    options = [
      restart: :transient,
      shutdown: 5_000
    ]

    args = [xmlel, domain, otp_app]

    Task.Supervisor.start_child(@task_sup, __MODULE__, :run, args, options)
  end

  def run(xmlel, domain, otp_app) do
    module = Application.get_env(otp_app, :router)
    conn = Conn.new(xmlel, domain)
    query = xmlel.children
    apply(module, :route, [conn, query])
  end
end

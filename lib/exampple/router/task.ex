defmodule Exampple.Router.Task do
  @moduledoc """
  Starts the handling of the stanza. This task is launched
  by `Exampple.Router.Task.Monitor` and it is using the
  `Exampple.Router` to route the stanza to the correct controller.
  """
  alias Exampple.Router.Conn

  @task_sup Exampple.Router.Task.Supervisor

  @doc """
  Starts the task under the `Exampple.Router.Task.Supervisor` providing
  the stanza in `xmlel` format, the `domain` for the component and the
  `otp_app` (application name).
  """
  def start(xmlel, domain, otp_app) do
    args = [xmlel, domain, otp_app]
    opts = [restart: :temporary]

    Task.Supervisor.start_child(@task_sup, __MODULE__, :run, args, opts)
  end

  @doc """
  Stops the task running in the process identified by the `pid` parameter
  using the supervisor to perform this action correctly.
  """
  def stop(pid) do
    Task.Supervisor.terminate_child(@task_sup, pid)
  end

  @doc """
  The code which is being ran by the task. The information provided
  is required to create the `Exampple.Router.Conn` struct so, we
  need the stanza as a `Exampple.Xml.Xmlel` struct into the `xmlel`
  parameter, the `domain` for the component and the `otp_app`
  (application) we are using as the main one of our project.
  """
  def run(xmlel, domain, otp_app) do
    module = Application.get_env(otp_app, :router)
    conn = Conn.new(xmlel, domain)
    query = xmlel.children
    module.route(conn, query)
  end
end

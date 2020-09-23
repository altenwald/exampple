defmodule Exampple.Application do
  @moduledoc false
  use Application

  @task_sup Exampple.Router.Task.Supervisor
  @mon_sup Exampple.Router.Task.Monitor.Supervisor

  def start(_type, _args) do
    children = [
      {Task.Supervisor, name: @task_sup},
      {DynamicSupervisor, strategy: :one_for_one, name: @mon_sup}
    ]

    opts = [strategy: :one_for_one, name: Exampple.Supervisor]
    Supervisor.start_link(children, opts)
  end
end

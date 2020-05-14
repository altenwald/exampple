defmodule Exampple.Application do
  @moduledoc false
  use Application

  def start(_type, _args) do
    children = [
      {Task.Supervisor, name: Exampple.Router.Task.Supervisor}
    ]

    opts = [strategy: :one_for_one, name: Exampple.Supervisor]
    Supervisor.start_link(children, opts)
  end
end

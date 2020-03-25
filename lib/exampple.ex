defmodule Exampple do
  @moduledoc """
  Exampple is a XMPP Component framework to develop solutions based on
  SOA 2.0. This framework let you to create different services connected
  to a XMPP server and provide more functionality to your environment.
  """

  @app_name Mix.Project.config() |> Keyword.fetch!(:app)

  @doc false
  def start_link([app]) when is_atom(app) do
    args =
      @app_name
      |> Application.get_env(Exampple.Component)
      |> Enum.into(%{})

    GenStateMachine.start_link(Exampple.Component, args, name: Exampple.Component)
  end

  def start_link([args]) do
    GenStateMachine.start_link(Exampple.Component, args, name: Exampple.Component)
  end

  @doc false
  def child_spec(args) do
    %{
      id: Exampple,
      start: {Exampple, :start_link, [args]},
      restart: :permanent,
      shutdown: 5_000
    }
  end
end

defmodule Exampple do
  @moduledoc """
  Exampple is a XMPP Component framework to develop solutions based on
  SOA 2.0. This framework let you to create different services connected
  to a XMPP server and provide more functionality to your environment.
  """

  @doc false
  def start_link(otp_app: otp_app) when is_atom(otp_app) do
    args =
      otp_app
      |> Application.get_env(Exampple.Component)
      |> Enum.into(%{})
      |> Map.put(:otp_app, otp_app)

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

defmodule Exampple do
  @moduledoc """
  Exampple is a XMPP Component framework to develop solutions based on
  SOA 2.0. This framework let you to create different services connected
  to a XMPP server and provide more functionality to your environment.
  """

  @doc false
  defdelegate start_link(args), to: Exampple.Component

  @doc false
  defdelegate child_spec(args), to: Exampple.Component
end

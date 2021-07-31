defmodule Exampple.Xmpp.Rpc do
  @moduledoc """
  To use Jabber-RPC you will need to add this module into your router
  in this way:

  ```elixir
  includes(Exampple.Xmpp.Rpc)
  ```

  And also, add the configuration for your `MyRpc` module which should
  contains all of your public functions accesible from Jabber-RPC:

  ```elixir
  config :exampple,
    router: MyRouter,
    rpc: MyRpc
  ```

  Once you have that, you can create functions inside of `MyRpc` and those
  could be called from XMPP. Keep in mind this is not controlling the security
  about how is using these RPC commands so, it's intended these functions
  should be public actions available for all of the users into the server.
  """
  use Exampple.Router

  iq "jabber:iq" do
    set("rpc", Exampple.Xmpp.Rpc.Controller, :rpc)
  end
end

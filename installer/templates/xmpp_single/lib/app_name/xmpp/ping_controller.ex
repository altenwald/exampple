defmodule <%= app_module %>.Xmpp.PingController do
  use Exampple.Component

  def ping(conn, _query) do
    conn
    |> iq_resp([])
    |> send()
  end
end

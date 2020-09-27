defmodule <%= app_module %>.Xmpp.ErrorController do
  use Exampple.Component

  def error(conn, _query) do
    conn
    |> iq_error("feature-not-implemented")
    |> send()
  end
end

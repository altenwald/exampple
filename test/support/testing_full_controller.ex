defmodule TestingFullController do
  alias Exampple.Xmpp
  require Exampple.Xmpp.Error
  def get(conn, stanza), do: send(:test_get_and_set, {:ok, :get, conn, stanza})
  def set(conn, stanza), do: send(:test_get_and_set, {:ok, :set, conn, stanza})
  def error(conn, stanza), do: send(:test_get_and_set, {:ok, :error, conn, stanza})
  def chat(conn, stanza), do: send(:test_get_and_set, {:ok, :chat, conn, stanza})
  def groupchat(conn, stanza), do: send(:test_get_and_set, {:ok, :groupchat, conn, stanza})
  def headline(conn, stanza), do: send(:test_get_and_set, {:ok, :headline, conn, stanza})
  def normal(_conn, _stanza), do: Xmpp.Error.fire_up!("service-unavailable", "¡fuego!", "es")

  def register(conn, stanza) do
    conn2 = Exampple.Xmpp.Stanza.iq_resp(conn, stanza)
    send(:test_get_and_set, {:ok, conn, conn2.response})
  end
end

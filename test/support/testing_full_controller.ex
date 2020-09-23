defmodule TestingFullController do
  def get(conn, stanza), do: send(:test_get_and_set, {:ok, conn, stanza})
  def set(conn, stanza), do: send(:test_get_and_set, {:ok, conn, stanza})
  def error(conn, stanza), do: send(:test_get_and_set, {:ok, conn, stanza})
  def chat(conn, stanza), do: send(:test_get_and_set, {:ok, conn, stanza})
  def groupchat(conn, stanza), do: send(:test_get_and_set, {:ok, conn, stanza})
  def headline(conn, stanza), do: send(:test_get_and_set, {:ok, conn, stanza})
  def normal(_conn, _stanza), do: raise(ArgumentError)

  def register(conn, stanza) do
    conn2 = Exampple.Xmpp.Stanza.iq_resp(conn, stanza)
    send(:test_get_and_set, {:ok, conn, conn2.response})
  end
end

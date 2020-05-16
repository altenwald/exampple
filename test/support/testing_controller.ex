defmodule TestingController do
  def get(conn, stanza), do: send(:test_get_and_set, {:ok, conn, stanza})
end

defmodule Exampple.Router.ConnCase.Client do
  @doc """
  Starts the TCP server and subscribe the caller process. It is called
  by the setup macro injected when ConnCase is used.
  """
  defmacro start_tcp() do
    quote do
      Exampple.DummyTcpClient.dump()
      Exampple.Client.connect()
      Exampple.Client.wait_for_connected()
      Exampple.DummyTcpClient.subscribe()
    end
  end

  @doc """
  The `client_received` macro injects a stanza inside of the client.
  The stanza should be in `%Xmlel{}` format or a binary chunk.

  See `Exampple.DummyTcpClient.received/1` for further information.
  """
  defmacro client_received(stanza) do
    quote do
      Exampple.DummyTcpClient.received(unquote(stanza))
    end
  end

  @doc """
  The `assert_stanza_received` macro asks to DummyTcpClient for a stanza received
  and compares it to the stanza passed as parameter. If there is no stanzas
  received previously, `nil` is returned.
  """
  defmacro assert_stanza_received(stanza) do
    quote do
      assert {unquote(stanza), _} = Exampple.Xml.Xmlel.parse(Exampple.DummyTcpClient.sent())
    end
  end

  @doc """
  The `assert_stanza_receive` macro receives a message in the process and
  checks it out against the stanza passed as a parameter. It waits for
  an incoming stanza for the timeout passed as second parameter. By
  default the second parameter is configured to 5 seconds.
  """
  defmacro assert_stanza_receive(stanza, timeout \\ 5_000) do
    quote do
      assert unquote(stanza) == Exampple.DummyTcpClient.wait_for_sent_xml(unquote(timeout))
    end
  end

  @doc """
  The `assert_all_stanza_receive` macro receives as many messages as
  needed to match the list of stanzas passed as the first parameter
  in the process and checks it out against the list of stanzas passed as
  the first parameter. It waits for an incoming stanza for the timeout
  passed as second parameter. By default the second parameter is
  configured to 5 seconds.
  """
  defmacro assert_all_stanza_receive(stanzas, timeout \\ 5_000) do
    quote do
      Exampple.DummyTcpClient.are_all_sent?(unquote(stanzas), unquote(timeout))
    end
  end

  @doc """
  The `stanza_receive` macro waits for a message during the timeout
  passed as a parameter or 5 seconds by default.
  """
  defmacro stanza_receive(timeout \\ 5_000) do
    quote do
      Exampple.DummyTcpClient.wait_for_sent_xml(unquote(timeout))
    end
  end

  @doc """
  The `stanza_received` macro ask for a previously received stanza to
  DummyTcpClient. If there is no stanzas waiting then it returns `nil`.
  """
  defmacro stanza_received() do
    quote do
      Exampple.DummyTcpClient.sent()
    end
  end
end

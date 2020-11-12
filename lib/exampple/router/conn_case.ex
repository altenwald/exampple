defmodule Exampple.Router.ConnCase do
  @moduledoc """
  ConnCase is used for tests. When a test is using this module
  we have available the start of the Exampple behaviours, DummyTcp
  server and the different asserts.
  """
  defmacro __using__(_) do
    quote do
      use ExUnit.Case
      import Exampple.Router.ConnCase

      setup do
        start_tcp()
      end
    end
  end

  @doc """
  Starts the TCP server and subscribe the caller process. It is called
  by the setup macro injected when ConnCase is used.
  """
  defmacro start_tcp() do
    quote do
      Exampple.DummyTcp.dump()
      Exampple.Component.wait_for_ready()
      Exampple.DummyTcp.subscribe()
    end
  end

  @doc """
  The `component_received` macro injects a stanza inside of the component.
  The stanza should be in `%Xmlel{}` format.
  """
  defmacro component_received(stanza) do
    quote do
      Exampple.DummyTcp.received(unquote(stanza))
    end
  end

  @doc """
  The `assert_stanza_received` macro asks to DummyTcp for a stanza received
  and compares it to the stanza passed as parameter. If there is no stanzas
  received previously, `nil` is returned.
  """
  defmacro assert_stanza_received(stanza) do
    quote do
      assert {unquote(stanza), _} = Exampple.Xml.Xmlel.parse(Exampple.DummyTcp.sent())
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
      assert unquote(stanza) == Exampple.DummyTcp.wait_for_sent_xml(unquote(timeout))
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
      Exampple.DummyTcp.are_all_sent?(unquote(stanzas), unquote(timeout))
    end
  end

  @doc """
  The `stanza_receive` macro waits for a message during the timeout
  passed as a parameter or 5 seconds by default.
  """
  defmacro stanza_receive(timeout \\ 5_000) do
    quote do
      Exampple.DummyTcp.wait_for_sent_xml(unquote(timeout))
    end
  end

  @doc """
  The `stanza_received` macro ask for a previously received stanza to
  DummyTcp. If there is no stanzas waiting then it returns `nil`.
  """
  defmacro stanza_received() do
    quote do
      Exampple.DummyTcp.sent()
    end
  end
end

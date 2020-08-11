defmodule Exampple.Router.ConnCase do
  defmacro __using__(_) do
    quote do
      use ExUnit.Case
      import Exampple.Router.ConnCase

      setup do
        DummyTcp.dump()
        Component.wait_for_ready()
        DummyTcp.subscribe()
      end
    end
  end

  defmacro component_received(stanza) do
    quote do
      Exampple.DummyTcp.received(unquote(stanza))
    end
  end

  defmacro assert_stanza_received(stanza) do
    quote do
      assert unquote(stanza) = Exampple.Xml.Xmlel.parse(Exampple.DummyTcp.sent())
    end
  end

  defmacro assert_stanza_receive(stanza, timeout \\ 5_000) do
    quote do
      assert unquote(stanza) = Exampple.DummyTcp.wait_for_sent_xml(unquote(timeout))
    end
  end

  defmacro assert_all_stanza_receive(stanzas, timeout \\ 5_000) do
    quote do
      Exampple.DummyTcp.are_all_sent?(unquote(stanzas), unquote(timeout))
    end
  end
end

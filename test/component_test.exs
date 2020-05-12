defmodule Exampple.ComponentTest do
  use ExUnit.Case

  import Exampple.Xml.Xmlel

  alias Exampple.{Component, DummyTcp, Router}
  alias Exampple.Xmpp.Stanza

  defmodule TestingRouter do
    def route(xmlel, domain, _otp_app) do
      xmlel
      |> Router.build_conn(domain)
      |> Stanza.iq_resp()
      |> Component.send()
    end
  end

  setup do
    config =
      :exampple
      |> Application.get_env(Exampple.Component)
      |> Keyword.put(:router_handler, TestingRouter)

    Application.put_env(:exampple, Exampple.Component, config)
  end

  describe "connectivity" do
    test "starting" do
      Exampple.start_link(otp_app: :exampple)
      assert {:disconnected, %Component.Data{}} = :sys.get_state(Component)
      Component.stop()
    end

    test "connecting" do
      Exampple.start_link(otp_app: :exampple)
      Component.connect()
      Component.wait_for_ready()
      assert {:ready, %Component.Data{}} = :sys.get_state(Component)
      assert nil == DummyTcp.sent()
      DummyTcp.dump()
      Component.stop()
    end

    test "checking postpone when disconnected" do
      Exampple.start_link(otp_app: :exampple)

      iq = ~x[<iq type='get' from='test.example.com' to='you' id='1'/>]

      Component.send(to_string(iq))
      assert {:disconnected, %Component.Data{}} = :sys.get_state(Component)

      Component.connect()
      Component.wait_for_ready()
      Process.sleep(500)

      assert iq == parse(DummyTcp.sent())
      DummyTcp.dump()
      DummyTcp.stop()
    end

    test "ping" do
      Exampple.start_link(otp_app: :exampple)
      Component.connect()
      Component.wait_for_ready()
      DummyTcp.subscribe()

      DummyTcp.received(~x[
        <iq type='get' to='test.example.com' from='User@example.com/res1' id='1'>
          <query xmlns='jabber:iq:ping'/>
        </iq>
      ])

      recv = ~x[
        <iq from="test.example.com" id="1" to="User@example.com/res1" type="result">
          <query xmlns="jabber:iq:ping"/>
        </iq>
      ]

      assert recv == DummyTcp.wait_for_sent_xml()
      assert recv == parse(DummyTcp.sent())
      Component.stop()
      DummyTcp.dump()
      DummyTcp.stop()
    end
  end
end

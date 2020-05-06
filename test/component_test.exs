defmodule Exampple.ComponentTest do
  use ExUnit.Case

  import Exampple.Xml.Xmlel

  alias Exampple.{Component, DummyTcp, Router}
  alias Exampple.Xmpp.Stanza

  defmodule TestingRouter do
    require Logger

    def route(xmlel, _domain, _otp_app) do
      xmlel
      |> Router.build_conn()
      |> Stanza.iq_resp()
      |> Component.send()
    end
  end

  describe "connectivity" do
    setup do
      config =
        :exampple
        |> Application.get_env(Exampple.Component)
        |> Keyword.put(:router_handler, TestingRouter)

      Application.put_env(:exampple, Exampple.Component, config)
    end

    test "starting" do
      Exampple.start_link(otp_app: :exampple)
      assert {:disconnected, %Component.Data{}} = :sys.get_state(Component)
      Component.stop()
    end

    test "connecting" do
      Exampple.start_link(otp_app: :exampple)
      Component.connect()
      Process.sleep(500)
      assert {:ready, %Component.Data{}} = :sys.get_state(Component)
      assert nil == DummyTcp.sent()
      Component.stop()
    end

    test "ping" do
      Exampple.start_link(otp_app: :exampple)
      Component.connect()
      Component.wait_for_ready()
      DummyTcp.subscribe()

      DummyTcp.received(~x[
        <iq type='get' to='test.example.com' from='user@example.com/res1' id='1'>
          <query xmlns='jabber:iq:ping'/>
        </iq>
      ])

      recv = ~x[
        <iq from="test.example.com" id="1" to="user@example.com/res1" type="result">
          <query xmlns="jabber:iq:ping"/>
        </iq>
      ]

      assert recv == DummyTcp.wait_for_sent_xml()
      assert recv == parse(DummyTcp.sent())
      Component.stop()
      DummyTcp.stop()
    end
  end
end

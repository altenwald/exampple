defmodule Exampple.ComponentTest do
  use ExUnit.Case, async: false

  import Exampple.Xml.Xmlel
  import Exampple.Router.ConnCase.Component

  alias Exampple.{Component, DummyTcpComponent}
  alias Exampple.Router.Conn
  alias Exampple.Xmpp.{Envelope, Stanza}

  defmodule TestingRouter do
    def maybe_envelope(%Conn{xmlns: "urn:xmpp:delegation:1"} = conn) do
      stanza = conn.stanza.children

      case Envelope.handle(conn, stanza) do
        {conn, _stanza} -> conn
        nil -> conn
      end
    end

    def maybe_envelope(conn), do: conn

    def route(xmlel, domain, _otp_app, _timeout) do
      xmlel
      |> Conn.new(domain)
      |> maybe_envelope()
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
    Exampple.start_link(otp_app: :exampple)
    Component.disconnect()
    on_exit(fn -> DummyTcpComponent.dump() end)
  end

  describe "connectivity" do
    test "starting" do
      assert {:disconnected, %Component.Data{}} = :sys.get_state(Component)
    end

    test "connecting" do
      Component.connect()
      Component.wait_for_ready()
      assert {:ready, %Component.Data{}} = :sys.get_state(Component)
      assert nil == DummyTcpComponent.sent()
    end

    test "error connecting" do
      config =
        :exampple
        |> Application.get_env(Exampple.Component)
        |> Keyword.put(:password, "wrong")

      old_config = Application.get_env(:exampple, Exampple.Component)
      Application.put_env(:exampple, Exampple.Component, config)

      Component.stop()
      {:ok, pid} = Exampple.start_link(otp_app: :exampple)
      Process.unlink(pid)
      Process.monitor(pid)
      Component.connect()

      assert_receive {:DOWN, _ref, :process, ^pid, {%ArgumentError{}, _stacktrace}}, 500
      refute Process.alive?(pid)
      Application.put_env(:exampple, Exampple.Component, old_config)
    end
  end

  describe "handling stanzas" do
    test "checking postpone when disconnected" do
      iq = ~x[<iq type='get' from='test.example.com' to='you' id='1'/>]

      Component.send(to_string(iq))
      assert {:disconnected, %Component.Data{}} = :sys.get_state(Component)

      Component.connect()
      Component.wait_for_ready()
      Process.sleep(500)

      assert {^iq, _} = parse(DummyTcpComponent.sent())
    end

    test "ping" do
      Component.connect()
      Component.wait_for_ready()
      DummyTcpComponent.subscribe()

      component_received(~x[
        <iq type='get' to='test.example.com' from='User@example.com/res1' id='1'>
          <query xmlns='jabber:iq:ping'/>
        </iq>
      ])

      stanza = ~x[
        <iq from="test.example.com" id="1" to="User@example.com/res1" type="result">
          <query xmlns="jabber:iq:ping"/>
        </iq>
      ]

      assert_stanza_receive(stanza)
      assert_stanza_received(^stanza)
    end

    test "ping disconnected" do
      Component.connect()
      Component.wait_for_ready()
      DummyTcpComponent.subscribe()

      Process.sleep(500)
      Component.disconnect()
      Process.sleep(750)
      assert is_pid(Process.whereis(Exampple.Component))
    end

    test "stanzas" do
      Component.connect()
      Component.wait_for_ready()
      DummyTcpComponent.subscribe()

      component_received(~x[
        <iq type='get' to='test.example.com' from='User@example.com/res1' id='1'>
          <query xmlns='jabber:iq:ping'/>
        </iq>
      ])
      component_received(~x[
        <iq type='get' to='test.example.com' from='User@example.com/res1' id='2'>
          <query xmlns='jabber:iq:ping'/>
        </iq>
      ])

      assert_all_stanza_receive([
        ~x[
        <iq from="test.example.com" id="1" to="User@example.com/res1" type="result">
          <query xmlns="jabber:iq:ping"/>
        </iq>
        ],
        ~x[
        <iq from="test.example.com" id="2" to="User@example.com/res1" type="result">
          <query xmlns="jabber:iq:ping"/>
        </iq>
        ]
      ])
    end

    test "chunks stanzas" do
      Component.connect()
      Component.wait_for_ready()
      DummyTcpComponent.subscribe()

      component_received(
        "<iq type='get' to='test.example.com' from='User@example.com/res1' id='1'>" <>
          "<query xmlns='jabber:iq:ping'/>" <>
          "</iq><iq type='get' to='test.example.com' from='User@example.com/res1' id='2'>" <>
          "<query xmlns='jabbe"
      )

      Process.sleep(100)
      component_received("r:iq:ping'/></iq>")

      assert_stanza_receive(~x[
        <iq from="test.example.com" id="1" to="User@example.com/res1" type="result">
          <query xmlns="jabber:iq:ping"/>
        </iq>
      ])

      assert_stanza_receive(~x[
        <iq from="test.example.com" id="2" to="User@example.com/res1" type="result">
          <query xmlns="jabber:iq:ping"/>
        </iq>
      ])
    end
  end

  describe "envelope" do
    test "with register" do
      Component.connect()
      Component.wait_for_ready()
      DummyTcpComponent.subscribe()

      component_received(~x[
        <iq from="example.com"
            id="rr-1589541841199-6202528975393777179-M1Gu8YC3x1EVFBl6bfW6FIECFP4=-55238004"
            to="test.example.com"
            type="set">
          <delegation xmlns="urn:xmpp:delegation:1">
            <forwarded xmlns="urn:xmpp:forward:0">
              <iq id="aab6a" to="example.com" type="get" xml:lang="en" xmlns="jabber:client">
                <query xmlns="jabber:iq:register"/>
              </iq>
            </forwarded>
          </delegation>
        </iq>
      ])

      stanza = ~x[
        <iq to="example.com"
            id="rr-1589541841199-6202528975393777179-M1Gu8YC3x1EVFBl6bfW6FIECFP4=-55238004"
            from="test.example.com"
            type="result">
          <delegation xmlns='urn:xmpp:delegation:1'>
            <forwarded xmlns='urn:xmpp:forward:0'>
              <iq id="aab6a" from="example.com" type="result">
                <query xmlns="jabber:iq:register"/>
              </iq>
            </forwarded>
          </delegation>
        </iq>
      ]

      assert_stanza_receive(stanza)
      assert_stanza_received(^stanza)
    end
  end
end

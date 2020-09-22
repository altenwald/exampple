defmodule Exampple.RouterTest do
  use ExUnit.Case, async: false
  require Logger

  import Exampple.Router.ConnCase
  import Exampple.Xml.Xmlel

  alias Exampple.Component
  alias Exampple.Router.Conn
  alias Exampple.Xmpp.Stanza

  describe "defining routes" do
    test "wrong controller module for router definition" do
      assert_raise ArgumentError, fn ->
        defmodule TestingRouterFail do
          use Exampple.Router

          iq "urn:exampple:test:" do
            get("get:0", TestingControllerFail, :get)
            set("set:0", TestingControllerFail, :set)
          end
        end
      end
    end

    test "wrong function in controller for router definition" do
      assert_raise ArgumentError, fn ->
        defmodule TestingRouterFailFunction do
          use Exampple.Router

          iq "urn:exampple:test:" do
            get("get:0", TestingController, :no_get)
            set("set:0", TestingController, :no_set)
          end
        end
      end
    end

    test "check info" do
      info = [
        {"message", "error", "", TestingFullController, :error},
        {"message", "normal", "", TestingFullController, :normal},
        {"message", "headline", "", TestingFullController, :headline},
        {"message", "groupchat", "", TestingFullController, :groupchat},
        {"message", "chat", "", TestingFullController, :chat},
        {"iq", "get", "jabber:iq:register", TestingFullController, :register},
        {"iq", "set", "urn:exampple:test:set:0", TestingFullController, :set},
        {"iq", "get", "urn:exampple:test:get:0", TestingController, :get}
      ]

      assert info == TestingFullRouter.route_info(:paths)
    end
  end

  describe "using routes" do
    setup do
      Application.put_env(:exampple, :router, TestingFullRouter)

      on_exit(:router, fn ->
        Application.put_env(:exampple, :router, TestingRouter)
      end)
    end

    test "check get and set" do
      stanza = ~x[<iq type='set'><query xmlns="urn:exampple:test:set:0"/></iq>]
      domain = "example.com"

      conn = %Exampple.Router.Conn{
        domain: "example.com",
        stanza_type: "iq",
        type: "set",
        xmlns: "urn:exampple:test:set:0",
        stanza: stanza
      }

      query = stanza.children

      Process.register(self(), :test_get_and_set)
      assert {:ok, _pid} = Exampple.Router.route(stanza, domain, :exampple)

      assert_receive {:ok, ^conn, ^query}
    end

    test "disco#info" do
      config =
        :exampple
        |> Application.get_env(Exampple.Component)
        |> Keyword.put(:router_handler, Exampple.Router)

      Application.put_env(:exampple, Exampple.Component, config)
      Exampple.start_link(otp_app: :exampple)
      Component.connect()
      start_tcp()

      ~x[
        <iq from='you' to='test.example.com' type='get' id='5'>
          <query xmlns='http://jabber.org/protocol/disco#info'/>
        </iq>
      ]
      |> component_received()

      assert_stanza_receive(~x[
        <iq from='test.example.com' to='you' type='result' id='5'>
          <query xmlns='http://jabber.org/protocol/disco#info'>
            <identity category="component" name="Testing component" type="generic"/>
            <feature var="jabber:iq:register"/>
            <feature var="urn:exampple:test:set:0"/>
            <feature var="urn:xmpp:forward:0"/>
            <feature var="urn:xmpp:delegation:1"/>
            <feature var="urn:exampple:test:get:0"/>
          </query>
        </iq>
      ])
    end

    test "check envelope" do
      stanza = ~x[
        <iq from='you' to='me' type='set'>
          <delegation xmlns='urn:xmpp:delegation:1'>
            <forwarded xmlns='urn:xmpp:forward:0'>
              <iq from='other' to='you' type='set'><query xmlns="urn:exampple:test:set:0"/></iq>
            </forwarded>
          </delegation>
        </iq>
      ]
      domain = "example.com"

      query = [~x[<query xmlns="urn:exampple:test:set:0"/>]]

      Process.register(self(), :test_get_and_set)
      assert {:ok, _pid} = Exampple.Router.route(stanza, domain, :exampple)

      assert_receive {:ok, conn, ^query}
      reply = ~x[
        <iq from='me' to='you' type='result'>
          <delegation xmlns='urn:xmpp:delegation:1'>
            <forwarded xmlns='urn:xmpp:forward:0'>
              <iq from='you' to='other' type='result'><query xmlns="urn:exampple:test:set:0"/></iq>
            </forwarded>
          </delegation>
        </iq>
      ]

      assert reply == parse(Conn.get_response(Stanza.iq_resp(conn)))
    end

    test "check envelope without from or to" do
      stanza = ~x[
        <iq from="example.com"
            id="rr-1589541841199-6202528975393777179-M1Gu8YC3x1EVFBl6bfW6FIECFP4=-55238004" 
            to="component.example.com"
            type="set">
          <delegation xmlns="urn:xmpp:delegation:1">
            <forwarded xmlns="urn:xmpp:forward:0">
              <iq id="aab6a" to="example.com" type="get" xml:lang="en" xmlns="jabber:client">
                <query xmlns="jabber:iq:register"/>
              </iq>
            </forwarded>
          </delegation>
        </iq>
      ]
      domain = "example.com"

      Process.register(self(), :test_get_and_set)
      assert {:ok, _pid} = Exampple.Router.route(stanza, domain, :exampple)

      reply = ~x[
        <iq to="example.com"
            id="rr-1589541841199-6202528975393777179-M1Gu8YC3x1EVFBl6bfW6FIECFP4=-55238004" 
            from="component.example.com"
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
      iq = ~x[
        <iq id="aab6a" from="example.com" type="result">
          <query xmlns="jabber:iq:register"/>
        </iq>
      ]
      assert_receive {:ok, conn, ^iq}

      assert reply == parse(Conn.get_response(Stanza.iq_resp(conn)))
    end
  end
end

defmodule Exampple.RouterTest do
  use ExUnit.Case

  import Exampple.Xml.Xmlel

  alias Exampple.Router.Conn
  alias Exampple.Xmpp.Stanza

  defmodule TestingController do
    def get(conn, stanza), do: send(:test_get_and_set, {:ok, conn, stanza})
    def set(conn, stanza), do: send(:test_get_and_set, {:ok, conn, stanza})
    def error(conn, stanza), do: send(:test_get_and_set, {:ok, conn, stanza})
    def chat(conn, stanza), do: send(:test_get_and_set, {:ok, conn, stanza})
    def groupchat(conn, stanza), do: send(:test_get_and_set, {:ok, conn, stanza})
    def headline(conn, stanza), do: send(:test_get_and_set, {:ok, conn, stanza})
    def normal(conn, stanza), do: send(:test_get_and_set, {:ok, conn, stanza})

    def register(conn, stanza) do
      conn2 = Stanza.iq_resp(conn, stanza)
      send(:test_get_and_set, {:ok, conn, conn2.response})
    end
  end

  defmodule TestingRouter do
    use Exampple.Router

    envelope(["urn:xmpp:delegation:1", "urn:xmpp:forward:0"])

    iq "urn:exampple:test:" do
      get("get:0", Exampple.RouterTest.TestingController, :get)
      set("set:0", Exampple.RouterTest.TestingController, :set)
    end

    iq "jabber:iq:" do
      get("register", Exampple.RouterTest.TestingController, :register)
    end

    message do
      chat(Exampple.RouterTest.TestingController, :chat)
      groupchat(Exampple.RouterTest.TestingController, :groupchat)
      headline(Exampple.RouterTest.TestingController, :headline)
      normal(Exampple.RouterTest.TestingController, :normal)
      error(Exampple.RouterTest.TestingController, :error)
    end

    fallback(Exampple.RouterTest.TestingController, :error)
  end

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
            get("get:0", Exampple.RouterTest.TestingController, :no_get)
            set("set:0", Exampple.RouterTest.TestingController, :no_set)
          end
        end
      end
    end

    test "check info" do
      info = [
        {"message", "error", "", Exampple.RouterTest.TestingController, :error},
        {"message", "normal", "", Exampple.RouterTest.TestingController, :normal},
        {"message", "headline", "", Exampple.RouterTest.TestingController, :headline},
        {"message", "groupchat", "", Exampple.RouterTest.TestingController, :groupchat},
        {"message", "chat", "", Exampple.RouterTest.TestingController, :chat},
        {"iq", "get", "jabber:iq:register", Exampple.RouterTest.TestingController, :register},
        {"iq", "set", "urn:exampple:test:set:0", TestingController, :set},
        {"iq", "get", "urn:exampple:test:get:0", TestingController, :get}
      ]

      assert info == TestingRouter.route_info()
    end

    test "check get and set" do
      Application.put_env(:exampple, :router, TestingRouter)

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

    test "check envelope" do
      Application.put_env(:exampple, :router, TestingRouter)

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
      Application.put_env(:exampple, :router, TestingRouter)

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

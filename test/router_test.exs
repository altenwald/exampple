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
  end

  defmodule TestingRouter do
    use Exampple.Router

    envelope ["urn:xmpp:delegation:1", "urn:xmpp:forward:0"]

    iq "urn:exampple:test:" do
      get("get:0", Exampple.RouterTest.TestingController, :get)
      set("set:0", Exampple.RouterTest.TestingController, :set)
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
  end
end

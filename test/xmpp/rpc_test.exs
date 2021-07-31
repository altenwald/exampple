defmodule Exampple.Xmpp.Rpc.ControllerTest do
  use ExUnit.Case, async: false

  import Exampple.Xml.Xmlel
  import Exampple.Router.ConnCase.Component

  alias Exampple.{Component, DummyTcpComponent}

  setup do
    Application.put_env(:exampple, :router, TestingFullRouter)

    config =
      :exampple
      |> Application.get_env(Exampple.Component)
      |> Keyword.put(:router_handler, Exampple.Router)

    Application.put_env(:exampple, Exampple.Component, config)
    Exampple.start_link(otp_app: :exampple)
    Component.disconnect()
    Component.connect()

    start_tcp()

    on_exit(fn -> DummyTcpComponent.dump() end)
  end

  describe "rpc" do
    test "sum ints" do
      component_received(~x[
        <iq to='test.example.com' from='romeo@example.com/res' id='1' type='set'>
          <query xmlns='jabber:iq:rpc'>
            <methodCall>
              <methodName>sum_int</methodName>
              <params>
                <param>
                  <value><int>12</int></value>
                </param>
                <param>
                  <value><int>55</int></value>
                </param>
              </params>
            </methodCall>
          </query>
        </iq>
      ])

      assert_stanza_receive(~x[
        <iq from='test.example.com' to='romeo@example.com/res' id='1' type='result'>
          <query xmlns='jabber:iq:rpc'>
            <methodResponse>
              <params>
                <param>
                  <value><int>67</int></value>
                </param>
              </params>
            </methodResponse>
          </query>
        </iq>
      ])
    end
  end
end

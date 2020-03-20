defmodule Exampple.RouterTest do
  use ExUnit.Case

  defmodule TestingController do
    def get(conn, stanza), do: send(:test_get_and_set, {:ok, conn, stanza})
    def set(conn, stanza), do: send(:test_get_and_set, {:ok, conn, stanza})
  end

  defmodule TestingRouter do
    use Exampple.Router

    scope :iq do
      get "urn:exampple:test:get:0", Exampple.RouterTest.TestingController, :get
      set "urn:exampple:test:set:0", Exampple.RouterTest.TestingController, :set
    end
  end

  describe "defining routes" do
    test "check info" do
      info = [
        {"iq", "set", "urn:exampple:test:set:0", TestingController, :set},
        {"iq", "get", "urn:exampple:test:get:0", TestingController, :get}
      ]
      assert info == TestingRouter.route_info()
    end

    test "check get and set" do
      Application.put_env(:exampple, :router, TestingRouter)
      stanza = %Exampple.Saxy.Xmlel{
        name: "iq",
        attrs: %{"type" => "set"},
        children: [
          %Exampple.Saxy.Xmlel{
            name: "query",
            attrs: %{"xmlns" => "urn:exampple:test:set:0"}
          }
        ]
      }
      domain = "example.com"
      conn =
        %Exampple.Router.Conn{
          domain: "example.com",
          stanza_type: "iq",
          type: "set",
          xmlns: "urn:exampple:test:set:0"
        }
      Process.register(self(), :test_get_and_set)
      assert {:ok, _pid} = Exampple.Router.route(stanza, domain)
      received =
        receive do
          info -> info
        end
      assert {:ok, conn, stanza} == received
    end
  end
end

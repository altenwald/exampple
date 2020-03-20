defmodule Exampple.RouterTest do
  use ExUnit.Case

  defmodule TestingRouter do
    use Exampple.Router

    alias Exampple.RouterTest.TestingController

    scope :iq do
      get "urn:exampple:test:get:0", TestingController, :get
      set "urn:exampple:test:set:0", TestingController, :set
    end
  end

  defmodule TestingController do
    def get(conn, stanza), do: {:ok, conn, stanza}
    def set(conn, stanza), do: {:ok, conn, stanza}
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
      conn =
        %Exampple.Router.Conn{
          stanza_type: "iq",
          type: "set",
          xmlns: "urn:exampple:test:set:0"
        }
      stanza = %Exampple.Saxy.Xmlel{}
      assert {:ok, conn, stanza} == TestingRouter.route(conn, stanza)
    end
  end
end

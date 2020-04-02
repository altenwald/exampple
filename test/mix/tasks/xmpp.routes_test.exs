defmodule Mix.Tasks.Xmpp.RoutesTest do
  use ExUnit.Case, async: true
  import ExUnit.CaptureIO

  defmodule TestingController do
    def get(conn, stanza), do: send(:test_get_and_set, {:ok, conn, stanza})
  end

  defmodule TestingRouter do
    use Exampple.Router

    iq "urn:exampple:test:" do
      get("get:0", Exampple.RouterTest.TestingController, :get)
    end
  end

  describe "run/1" do
    test "no router configured" do
      Application.put_env(:exampple, :router, nil)

      output =
        capture_io(fn ->
          Mix.Tasks.Xmpp.Routes.run([])
        end)

      expected = """
      No router configured!
      """

      assert expected == output
    end

    test "print routes" do
      Application.put_env(:exampple, :router, TestingRouter)

      output =
        capture_io(fn ->
          Mix.Tasks.Xmpp.Routes.run([])
        end)

      expected = """
      [
        {"iq", "get", "urn:exampple:test:get:0",
         Exampple.RouterTest.TestingController, :get}
      ]
      """

      assert expected == output
    end
  end
end

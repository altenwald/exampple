defmodule Mix.Tasks.Xmpp.RoutesTest do
  use ExUnit.Case, async: true
  import ExUnit.CaptureIO

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
      [{"iq", "get", "urn:exampple:test:get:0", TestingController, :get}]
      """

      assert expected == output
    end
  end
end

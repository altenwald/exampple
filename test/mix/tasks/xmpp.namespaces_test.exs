defmodule Mix.Tasks.Xmpp.NamespacesTest do
  use ExUnit.Case, async: false
  import ExUnit.CaptureIO

  describe "run/1" do
    test "no router configured" do
      Application.put_env(:exampple, :router, nil)

      output =
        capture_io(fn ->
          Mix.Tasks.Xmpp.Namespaces.run([])
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
          Mix.Tasks.Xmpp.Namespaces.run([])
        end)

      expected = """
      urn:exampple:test:get:0
      """

      assert expected == output
    end
  end
end

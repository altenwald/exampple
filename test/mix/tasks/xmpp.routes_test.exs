defmodule Mix.Tasks.Xmpp.RoutesTest do
  use ExUnit.Case, async: false
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

      expected = [
        IO.ANSI.blue(),
        "iq ",
        IO.ANSI.yellow(),
        "get ",
        IO.ANSI.green(),
        "urn:exampple:test:get:0 ",
        IO.ANSI.white(),
        "TestingController ",
        IO.ANSI.red(),
        "get",
        IO.ANSI.reset(),
        "\n"
      ]

      assert to_string(expected) == output
    end
  end
end

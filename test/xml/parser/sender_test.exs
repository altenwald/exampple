defmodule Exampple.Xml.Parser.SenderTest do
  use ExUnit.Case

  alias Exampple.Xml.Stream, as: XmlStream

  describe "process a document" do
    test "correctly step by step (debug)" do
      Application.put_env(:exampple, :debug_xml, true)

      assert :ok =
               XmlStream.new()
               |> XmlStream.parse("<foo id='1'")
               |> XmlStream.parse(">Hello world!<bar>")
               |> XmlStream.parse("more data</bar>")
               |> XmlStream.parse("</foo>")
               |> XmlStream.terminate()

      xmlel = %Exampple.Xml.Xmlel{
        attrs: %{"id" => "1"},
        children: [
          "Hello world!",
          %Exampple.Xml.Xmlel{attrs: %{}, children: ["more data"], name: "bar"}
        ],
        name: "foo"
      }

      events = [
        :xmlstartdoc,
        {:xmlstreamstart, "foo", [{"id", "1"}]},
        {:xmlcdata, "Hello world!"},
        {:xmlstreamstart, "bar", []},
        {:xmlcdata, "more data"},
        {:xmlstreamend, "bar"},
        {:xmlstreamend, "foo"},
        {:xmlelement, xmlel},
        :xmlenddoc
      ]

      assert events == receive_all()
    end

    test "correctly step by step" do
      Application.put_env(:exampple, :debug_xml, false)

      assert :ok =
               XmlStream.new()
               |> XmlStream.parse("<foo id='1'")
               |> XmlStream.parse(">Hello world!<bar>")
               |> XmlStream.parse("more data</bar>")
               |> XmlStream.parse("<baz>and more</baz>")
               |> XmlStream.parse("</foo>")
               |> XmlStream.terminate()

      xmlel = %Exampple.Xml.Xmlel{
        attrs: %{"id" => "1"},
        children: [
          "Hello world!",
          %Exampple.Xml.Xmlel{attrs: %{}, children: ["more data"], name: "bar"},
          %Exampple.Xml.Xmlel{attrs: %{}, children: ["and more"], name: "baz"}
        ],
        name: "foo"
      }

      events = [
        {:xmlstreamstart, "foo", [{"id", "1"}]},
        {:xmlstreamstart, "bar", []},
        {:xmlstreamstart, "baz", []},
        {:xmlelement, xmlel}
      ]

      assert events == receive_all()
    end

    test "incorrect XML step by step" do
      assert {:error, _} =
               XmlStream.new()
               |> XmlStream.parse("<foo id='1'")
               |> XmlStream.parse(" Hello world!<bar>")
    end
  end

  defp receive_all(stack \\ []) do
    receive do
      other -> receive_all([other | stack])
    after
      0 ->
        Enum.reverse(stack)
    end
  end
end

defmodule Exampple.Xml.Parser.SenderTest do
  use ExUnit.Case, async: false

  alias Exampple.Xml.Stream, as: XmlStream
  alias Exampple.Xml.Xmlel
  import Exampple.Xml.Xmlel, only: [sigil_x: 2]

  describe "process a document" do
    test "correctly step by step (debug)" do
      Application.put_env(:exampple, :debug_xml, true)

      assert {:ok, ""} =
               XmlStream.new()
               |> XmlStream.parse("<foo id='1'")
               |> XmlStream.parse(">Hello world!<bar>")
               |> XmlStream.parse("more data</bar>")
               |> XmlStream.parse("</foo>")
               |> XmlStream.terminate()

      events = [
        :xmlstartdoc,
        {:xmlstreamstart, "foo", [{"id", "1"}]},
        {:xmlcdata, "Hello world!"},
        {:xmlstreamstart, "bar", []},
        {:xmlcdata, "more data"},
        {:xmlstreamend, "bar"},
        {:xmlstreamend, "foo"},
        {:xmlelement, ~x[<foo id="1">Hello world!<bar>more data</bar></foo>]}
      ]

      assert events == receive_all()
    end

    test "correctly step by step" do
      Application.put_env(:exampple, :debug_xml, false)

      assert {:ok, ""} =
               XmlStream.new()
               |> XmlStream.parse("<foo id='1'")
               |> XmlStream.parse(">Hello world!<bar>")
               |> XmlStream.parse("more data</bar>")
               |> XmlStream.parse("<baz>and more</baz>")
               |> XmlStream.parse("</foo>")
               |> XmlStream.terminate()

      events = [
        {:xmlstreamstart, "foo", [{"id", "1"}]},
        {:xmlstreamstart, "bar", []},
        {:xmlstreamstart, "baz", []},
        {:xmlelement, ~x[
          <foo id="1">Hello world!<bar>more data</bar><baz>and more</baz></foo>
        ]}
      ]

      assert events == receive_all()
    end

    test "correctly step by step in the middle of an attribute" do
      Application.put_env(:exampple, :debug_xml, false)

      assert {:ok, ""} =
               XmlStream.new()
               |> XmlStream.parse("<foo id='cef83a10-4084-4b94-afe9-")
               |> XmlStream.parse("5b528e8db468'")
               |> XmlStream.parse(">Hello world!<bar>")
               |> XmlStream.parse("more data</bar>")
               |> XmlStream.parse("</foo>")
               |> XmlStream.terminate()

      events = [
        {:xmlstreamstart, "foo", [{"id", "cef83a10-4084-4b94-afe9-5b528e8db468"}]},
        {:xmlstreamstart, "bar", []},
        {:xmlelement, ~x[
          <foo id="cef83a10-4084-4b94-afe9-5b528e8db468">Hello world!<bar>more data</bar></foo>
        ]}
      ]

      assert events == receive_all()
    end

    test "incorrect XML step by step" do
      assert {:error, _} =
               XmlStream.new()
               |> XmlStream.parse("<foo id='1'")
               |> XmlStream.parse(" Hello world!<bar>")
    end

    test "more than one stanza" do
      Application.put_env(:exampple, :debug_xml, false)

      assert {:ok, ""} =
               XmlStream.new()
               |> XmlStream.parse("<foo id='1'")
               |> XmlStream.parse(">Hello world!")
               |> XmlStream.parse("</foo>")
               |> XmlStream.parse("<bar>more data</bar>")
               |> XmlStream.parse("<baz>and more</baz>")
               |> XmlStream.terminate()

      events = [
        {:xmlstreamstart, "foo", [{"id", "1"}]},
        {:xmlelement, ~x[<foo id='1'>Hello world!</foo>]},
        {:xmlstreamstart, "bar", []},
        {:xmlelement, ~x[<bar>more data</bar>]},
        {:xmlstreamstart, "baz", []},
        {:xmlelement, ~x[<baz>and more</baz>]}
      ]

      assert events == receive_all()
    end

    test "more than one stanza split" do
      Application.put_env(:exampple, :debug_xml, false)

      assert {:ok, ""} =
               XmlStream.new()
               |> XmlStream.parse("<foo id='1'")
               |> XmlStream.parse(">Hello world!")
               |> XmlStream.parse("</foo><bar a='1")
               |> XmlStream.parse("23'>more data</bar>")
               |> XmlStream.parse("<baz>and more</baz>")
               |> XmlStream.terminate()

      events = [
        {:xmlstreamstart, "foo", [{"id", "1"}]},
        {:xmlelement, ~x[<foo id='1'>Hello world!</foo>]},
        {:xmlstreamstart, "bar", [{"a", "123"}]},
        {:xmlelement, ~x[<bar a='123'>more data</bar>]},
        {:xmlstreamstart, "baz", []},
        {:xmlelement, ~x[<baz>and more</baz>]}
      ]

      assert events == receive_all()
    end

    test "ignoring stream:stream (never ending tag)" do
      Application.put_env(:exampple, :debug_xml, false)

      assert {:halt, _, data} =
               XmlStream.new()
               |> XmlStream.parse(
                 "<?xml version='1.0'?><stream:stream id='17927389085261471095' version='1.0' xml:lang='en' xmlns:stream='http://etherx.jabber.org/streams' from='localhost' xmlns='jabber:client'><stream:features><bind xmlns='urn:ietf:params:xml:ns:xmpp-bind'/><session xmlns='urn:ietf:params:xml:ns:xmpp-session'><optional/></session><sm xmlns='urn:xmpp:sm:2'/><sm xmlns='urn:xmpp:sm:3'/></stream:features>"
               )

      events = [
        {:xmlstreamstart, "stream:stream",
         [
           {"id", "17927389085261471095"},
           {"version", "1.0"},
           {"xml:lang", "en"},
           {"xmlns:stream", "http://etherx.jabber.org/streams"},
           {"from", "localhost"},
           {"xmlns", "jabber:client"}
         ]}
      ]

      assert events == receive_all()

      assert {:halt, _, ""} =
               XmlStream.new()
               |> XmlStream.parse(data)

      events = [
        {:xmlstreamstart, "stream:features", []},
        {:xmlstreamstart, "bind", [{"xmlns", "urn:ietf:params:xml:ns:xmpp-bind"}]},
        {:xmlstreamstart, "session", [{"xmlns", "urn:ietf:params:xml:ns:xmpp-session"}]},
        {:xmlstreamstart, "optional", []},
        {:xmlstreamstart, "sm", [{"xmlns", "urn:xmpp:sm:2"}]},
        {:xmlstreamstart, "sm", [{"xmlns", "urn:xmpp:sm:3"}]},
        {:xmlelement,
         %Xmlel{
           children: [
             %Xmlel{
               attrs: %{"xmlns" => "urn:ietf:params:xml:ns:xmpp-bind"},
               name: "bind"
             },
             %Xmlel{
               attrs: %{"xmlns" => "urn:ietf:params:xml:ns:xmpp-session"},
               children: [%Xmlel{name: "optional"}],
               name: "session"
             },
             %Xmlel{
               attrs: %{"xmlns" => "urn:xmpp:sm:2"},
               name: "sm"
             },
             %Xmlel{
               attrs: %{"xmlns" => "urn:xmpp:sm:3"},
               name: "sm"
             }
           ],
           name: "stream:features"
         }}
      ]

      assert events == receive_all()
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

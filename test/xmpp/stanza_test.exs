defmodule Exampple.Xmpp.StanzaTest do
  use ExUnit.Case
  doctest Exampple.Xmpp.Stanza

  import Exampple.Xml.Xmlel, only: [sigil_x: 2]

  alias Exampple.Xml.Xmlel
  alias Exampple.Xmpp.Stanza

  defmodule Person do
    use Exampple.Xmpp.Stanza
    alias Exampple.Xml.Xmlel

    @impl Exampple.Xmpp.Stanza
    def render(person) do
      Xmlel.new("person", %{}, [
        Xmlel.new("name", %{}, [to_string(person.name)]),
        Xmlel.new("age", %{"years-old" => to_string(person.age)}, [])
      ])
    end

    defstruct name: nil, age: nil
  end

  describe "stanza tests" do
    test "check serialization" do
      alice = %Exampple.Xmpp.StanzaTest.Person{name: "Alice", age: 25}
      bob = %Exampple.Xmpp.StanzaTest.Person{name: "Bob", age: 21}

      assert "<person><name>Alice</name><age years-old=\"25\"/></person>" ==
               Saxy.encode!(Saxy.Builder.build(alice), nil)

      assert "<person><name>Bob</name><age years-old=\"21\"/></person>" ==
               Saxy.encode!(Saxy.Builder.build(bob), nil)
    end
  end

  @uuid "57acade8-1705-4862-b7bd-b190d864a1a9"

  describe "generate IDs" do
    setup do
      previous = Application.get_env(:exampple, :auto_generate_id)
      Application.put_env(:exampple, :auto_generate_id, true)
      Application.put_env(:exampple, :gen_uuid, @uuid)

      on_exit(:config, fn ->
        Application.put_env(:exampple, :auto_generate_id, previous)
      end)
    end

    test "check for IQ" do
      payload = [~x[<query xmlns='urn:xmpp:ping'/>]]
      from = "user@domain.com/res"

      assert ~x[
        <iq
          id='#{@uuid}'
          from='user@domain.com/res'
          type='set'>
          <query xmlns='urn:xmpp:ping'/>
        </iq>] == Stanza.iq(payload, from, nil, nil, "set")
    end

    test "raise an error if auto-generate is off and IQ has no ID" do
      Application.put_env(:exampple, :auto_generate_id, false)
      payload = [~x[<query xmlns='urn:xmpp:ping'/>]]
      from = "user@domain.com/res"

      assert_raise ArgumentError, fn ->
        Stanza.iq(payload, from, nil, nil, "set")
      end
    end

    test "not when is an IQ response" do
      stanza = ~x[
        <iq
          id='45'
          from='user@domain.com/res'
          type='set'>
          <query xmlns='urn:xmpp:ping'/>
        </iq>
      ]
      assert ~x[
        <iq
          id='45'
          to='user@domain.com/res'
          type='result'>
          <query xmlns='urn:xmpp:ping'/>
        </iq>
      ] == Stanza.iq_resp(stanza)
    end

    test "check for message" do
      payload = [~x[<body>Hello!</body>]]
      from = "user@domain.com"
      to = "another@domain.com"

      assert ~x[
        <message
          id='#{@uuid}'
          from='user@domain.com'
          to='another@domain.com'
          type='chat'>
          <body>Hello!</body>
        </message>] == Stanza.message(payload, from, nil, to, "chat")
    end
  end
end

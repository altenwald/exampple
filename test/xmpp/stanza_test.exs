defmodule Exampple.Xmpp.StanzaTest do
  use ExUnit.Case
  doctest Exampple.Xmpp.Stanza

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
end

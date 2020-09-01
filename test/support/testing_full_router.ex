defmodule TestingFullRouter do
  use Exampple.Router

  discovery do
    identity category: "component", type: "generic", name: "Testing component"
  end

  envelope(["urn:xmpp:delegation:1", "urn:xmpp:forward:0"])

  iq "urn:exampple:test:" do
    get("get:0", TestingFullController, :get)
    set("set:0", TestingFullController, :set)
  end

  iq "jabber:iq:" do
    get("register", TestingFullController, :register)
  end

  message do
    chat(TestingFullController, :chat)
    groupchat(TestingFullController, :groupchat)
    headline(TestingFullController, :headline)
    normal(TestingFullController, :normal)
    error(TestingFullController, :error)
  end

  fallback(TestingFullController, :error)
end

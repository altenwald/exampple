defmodule Exampple.Xmpp.Stanza do
  @moduledoc """
  Provides functions to create stanzas.
  """
  alias Exampple.Saxy.Xmlel

  @xmpp_stanzas "urn:ietf:params:xml:ns:xmpp-stanzas"

  @doc """
  Creates IQ stanzas.

  Examples:
    iex> payload = [Exampple.Saxy.Xmlel.new("query", %{"xmlns" => "jabber:iq:roster"})]
    iex> alice = "alice@example.com"
    iex> bob = "bob@example.com"
    iex> Exampple.Xmpp.Stanza.iq(payload, alice, "1", bob, "get")
    "<iq from=\\"alice@example.com\\" id=\\"1\\" to=\\"bob@example.com\\" type=\\"get\\"><query xmlns=\\"jabber:iq:roster\\"/></iq>"
  """
  def iq(payload, from, id, to, type) do
    stanza(payload, "iq", from, id, to, type)
  end

  @doc """
  Creates message stanzas.

  Examples:
    iex> payload = [Exampple.Saxy.Xmlel.new("body", %{}, ["hello world!"])]
    iex> alice = "alice@example.com"
    iex> bob = "bob@example.com"
    iex> Exampple.Xmpp.Stanza.message(payload, alice, "1", bob, "chat")
    "<message from=\\"alice@example.com\\" id=\\"1\\" to=\\"bob@example.com\\" type=\\"chat\\"><body>hello world!</body></message>"

    iex> payload = [Exampple.Saxy.Xmlel.new("composing")]
    iex> alice = "alice@example.com"
    iex> bob = "bob@example.com"
    iex> Exampple.Xmpp.Stanza.message(payload, alice, "1", bob)
    "<message from=\\"alice@example.com\\" id=\\"1\\" to=\\"bob@example.com\\"><composing/></message>"
  """
  def message(payload, from, id, to, type \\ nil) do
    stanza(payload, "message", from, id, to, type)
  end

  @doc """
  Creates presence stanzas.

  Examples:
    iex> alice = "alice@example.com"
    iex> Exampple.Xmpp.Stanza.presence([], alice, "1")
    "<presence from=\\"alice@example.com\\" id=\\"1\\"/>"
  """
  def presence(payload, from, id, to \\ nil, type \\ nil) do
    stanza(payload, "presence", from, id, to, type)
  end

  @doc """
  Creates error message stanzas.

  Examples:
    iex> payload = [Exampple.Saxy.Xmlel.new("body", %{}, ["hello world!"])]
    iex> alice = "alice@example.com"
    iex> bob = "bob@example.com"
    iex> Exampple.Xmpp.Stanza.message_error(payload, "item-not-found", alice, "1", bob)
    "<message from=\\"alice@example.com\\" id=\\"1\\" to=\\"bob@example.com\\" type=\\"error\\"><body>hello world!</body><error code=\\"404\\" type=\\"cancel\\"><error xmlns=\\"urn:ietf:params:xml:ns:xmpp-stanzas\\"/></error></message>"
  """
  def message_error(payload, error, from, id, to) do
    {code, type} = get_error(error)

    payload_error = [
      Xmlel.new("error", %{"code" => code, "type" => type}, [
        Xmlel.new("error", %{"xmlns" => @xmpp_stanzas})
      ])
    ]

    message(payload ++ payload_error, from, id, to, "error")
  end

  @doc """
  Taking an IQ stanza, it generates a response swapping from and to and
  changing the type to "result".

  Examples:
    iex> attrs = %{"from" => "alice@example.com", "to" => "bob@example.com", "id" => "1", "type" => "get"}
    iex> payload = Exampple.Saxy.Xmlel.new("query", %{"xmlns" => "jabber:iq:roster"})
    iex> xmlel = Exampple.Saxy.Xmlel.new("iq", attrs, [payload])
    iex> Exampple.Xmpp.Stanza.iq_resp(xmlel)
    "<iq from=\\"bob@example.com\\" id=\\"1\\" to=\\"alice@example.com\\" type=\\"result\\"><query xmlns=\\"jabber:iq:roster\\"/></iq>"
  """
  def iq_resp(%Xmlel{name: "iq", children: payload} = xmlel) do
    get = &Xmlel.get_attr(xmlel, &1)
    iq(payload, get.("to"), get.("id"), get.("from"), "result")
  end

  @doc """
  Taking an IQ stanza, it generates a response swapping from and to,
  changing the type to "result" and replacing payload using the
  provided as second parameter.

  Examples:
    iex> attrs = %{"from" => "alice@example.com", "to" => "bob@example.com", "id" => "1", "type" => "get"}
    iex> payload = Exampple.Saxy.Xmlel.new("query", %{"xmlns" => "jabber:iq:roster"})
    iex> xmlel = Exampple.Saxy.Xmlel.new("iq", attrs, [payload])
    iex> data = Exampple.Saxy.Xmlel.new("item", %{"id" => "1"}, ["contact 1"])
    iex> payload_resp = Exampple.Saxy.Xmlel.new("query", %{"xmlns" => "jabber:iq:roster"})
    iex> Exampple.Xmpp.Stanza.iq_resp(xmlel, [payload_resp])
    "<iq from=\\"bob@example.com\\" id=\\"1\\" to=\\"alice@example.com\\" type=\\"result\\"><query xmlns=\\"jabber:iq:roster\\">contact 1</query></iq>"
  """
  def iq_resp(%Xmlel{name: "iq"} = xmlel, payload) do
    get = &Xmlel.get_attr(xmlel, &1)
    iq(payload, get.("to"), get.("id"), get.("from"), "result")
  end

  @doc """
  Generates a result IQ stanza passing the payload, from JID, id and to JID.

  Examples:
    iex> from = "bob@example.com"
    iex> to = "alice@example.com"
    iex> id = "1"
    iex> payload = Exampple.Saxy.Xmlel.new("query", %{"xmlns" => "jabber:iq:roster"})
    iex> Exampple.Xmpp.Stanza.iq_resp([payload], from, id, to)
    "<iq from=\\"bob@example.com\\" id=\\"1\\" to=\\"alice@example.com\\" type=\\"result\\"><query xmlns=\\"jabber:iq:roster\\"/></iq>"

    iex> from = "bob@example.com"
    iex> to = "alice@example.com"
    iex> id = "1"
    iex> Exampple.Xmpp.Stanza.iq_resp(from, id, to)
    "<iq from=\\"bob@example.com\\" id=\\"1\\" to=\\"alice@example.com\\" type=\\"result\\"/>"
  """
  def iq_resp(payload \\ [], from, id, to) do
    iq(payload, from, id, to, "result")
  end

  @doc """
  Taken an IQ stanza, it generates an error based on error parameter.
  The codes available are the following ones:

  - bad-request
  - forbidden
  - item-not-found
  - not-acceptable
  - internal-server-error
  - service-unavailable
  - feature-not-implemented

  see more here: https://xmpp.org/extensions/xep-0086.html

  Examples:
    iex> attrs = %{"from" => "alice@example.com", "to" => "bob@example.com", "id" => "1", "type" => "get"}
    iex> payload = Exampple.Saxy.Xmlel.new("query", %{"xmlns" => "jabber:iq:roster"})
    iex> xmlel = Exampple.Saxy.Xmlel.new("iq", attrs, [payload])
    iex> Exampple.Xmpp.Stanza.iq_error(xmlel, "item-not-found")
    "<iq from=\\"bob@example.com\\" id=\\"1\\" to=\\"alice@example.com\\" type=\\"error\\"><query xmlns=\\"jabber:iq:roster\\"/><error code=\\"404\\" type=\\"cancel\\"><error xmlns=\\"urn:ietf:params:xml:ns:xmpp-stanzas\\"/></error></iq>"
  """
  def iq_error(%Xmlel{name: "iq", children: payload} = xmlel, error) do
    get = &Xmlel.get_attr(xmlel, &1)
    payload = payload ++ [error_tag(error)]
    iq(payload, get.("to"), get.("id"), get.("from"), "error")
  end

  @doc """
  Generates an error IQ stanza passing the payload, from JID, id and to JID.
  The codes available are the following ones:

  - bad-request
  - forbidden
  - item-not-found
  - not-acceptable
  - internal-server-error
  - service-unavailable
  - feature-not-implemented

  see more here: https://xmpp.org/extensions/xep-0086.html

  Examples:
    iex> from = "bob@example.com"
    iex> to = "alice@example.com"
    iex> id = "1"
    iex> payload = Exampple.Saxy.Xmlel.new("query", %{"xmlns" => "jabber:iq:roster"})
    iex> Exampple.Xmpp.Stanza.iq_error([payload], "item-not-found", from, id, to)
    "<iq from=\\"bob@example.com\\" id=\\"1\\" to=\\"alice@example.com\\" type=\\"error\\"><query xmlns=\\"jabber:iq:roster\\"/><error code=\\"404\\" type=\\"cancel\\"><error xmlns=\\"urn:ietf:params:xml:ns:xmpp-stanzas\\"/></error></iq>"
  """
  def iq_error(payload, error, from, id, to) do
    iq(payload ++ [error_tag(error)], from, id, to, "error")
  end

  @doc """
  Returns an error tag based on the key provided as parameter.
  The codes available are the following ones:

  - bad-request
  - forbidden
  - item-not-found
  - not-acceptable
  - internal-server-error
  - service-unavailable
  - feature-not-implemented

  see more here: https://xmpp.org/extensions/xep-0086.html

  Examples:
    iex> Exampple.Xmpp.Stanza.error_tag("item-not-found") |> to_string()
    "<error code=\\"404\\" type=\\"cancel\\"><error xmlns=\\"urn:ietf:params:xml:ns:xmpp-stanzas\\"/></error>"
  """
  def error_tag(error) do
    {code, type} = get_error(error)
    err_tag = Xmlel.new("error", %{"xmlns" => @xmpp_stanzas})
    Xmlel.new("error", %{"code" => code, "type" => type}, [err_tag])
  end

  defp maybe_add(attrs, _name, nil), do: attrs
  defp maybe_add(attrs, name, value), do: Map.put(attrs, name, value)

  def stanza(payload, stanza_type, from, id, to, type) do
    attrs =
      %{}
      |> maybe_add("id", id)
      |> maybe_add("from", from)
      |> maybe_add("to", to)
      |> maybe_add("type", type)

    Xmlel.new(stanza_type, attrs, payload)
    |> to_string()
  end

  ## took from: https://xmpp.org/extensions/xep-0086.html
  def get_error("bad-request"), do: {"400", "modify"}
  def get_error("forbidden"), do: {"403", "auth"}
  def get_error("item-not-found"), do: {"404", "cancel"}
  def get_error("not-acceptable"), do: {"406", "modify"}
  def get_error("internal-server-error"), do: {"500", "wait"}
  def get_error("service-unavailable"), do: {"503", "cancel"}
  def get_error("feature-not-implemented"), do: {"501", "cancel"}
end

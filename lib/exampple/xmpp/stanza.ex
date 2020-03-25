defmodule Exampple.Xmpp.Stanza do
  @moduledoc """
  Provides functions to create stanzas.
  """
  alias Exampple.Xml.Xmlel
  alias Exampple.Router.Conn

  @xmpp_stanzas "urn:ietf:params:xml:ns:xmpp-stanzas"

  @callback render(Map.t()) :: Xmlel.t()

  @doc false
  defmacro __using__(_) do
    quote do
      @behaviour Exampple.Xmpp.Stanza
      defimpl Saxy.Builder, for: __MODULE__ do
        @moduledoc false
        def build(%module{} = data) do
          data
          |> module.render()
          |> Xmlel.encode()
        end
      end
    end
  end

  @doc """
  Creates IQ stanzas.

  Examples:
    iex> payload = [Exampple.Xml.Xmlel.new("query", %{"xmlns" => "jabber:iq:roster"})]
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
    iex> payload = [Exampple.Xml.Xmlel.new("body", %{}, ["hello world!"])]
    iex> alice = "alice@example.com"
    iex> bob = "bob@example.com"
    iex> Exampple.Xmpp.Stanza.message(payload, alice, "1", bob, "chat")
    "<message from=\\"alice@example.com\\" id=\\"1\\" to=\\"bob@example.com\\" type=\\"chat\\"><body>hello world!</body></message>"

    iex> payload = [Exampple.Xml.Xmlel.new("composing")]
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
    iex> payload = [Exampple.Xml.Xmlel.new("body", %{}, ["hello world!"])]
    iex> alice = "alice@example.com"
    iex> bob = "bob@example.com"
    iex> Exampple.Xmpp.Stanza.message_error(payload, "item-not-found", alice, "1", bob)
    "<message from=\\"alice@example.com\\" id=\\"1\\" to=\\"bob@example.com\\" type=\\"error\\"><body>hello world!</body><error code=\\"404\\" type=\\"cancel\\"><item-not-found xmlns=\\"urn:ietf:params:xml:ns:xmpp-stanzas\\"/></error></message>"
  """
  def message_error(payload, error, from, id, to) do
    message(payload ++ [error_tag(error)], from, id, to, "error")
  end

  @doc """
  Creates a response error message inside of the Router.Conn struct (response).

  Examples:
    iex> payload = [Exampple.Xml.Xmlel.new("body", %{}, ["hello world!"])]
    iex> attrs = %{"from" => "alice@example.com", "to" => "bob@example.com", "id" => "1"}
    iex> message = Exampple.Xml.Xmlel.new("message", attrs, payload)
    iex> conn = Exampple.Router.build_conn(message)
    iex> |> Exampple.Xmpp.Stanza.message_error("item-not-found")
    iex> conn.response
    "<message from=\\"alice@example.com\\" id=\\"1\\" to=\\"bob@example.com\\" type=\\"error\\"><body>hello world!</body><error code=\\"404\\" type=\\"cancel\\"><item-not-found xmlns=\\"urn:ietf:params:xml:ns:xmpp-stanzas\\"/></error></message>"
  """
  def message_error(%Conn{} = conn, error) do
    from_jid = to_string(conn.from_jid)
    to_jid = to_string(conn.to_jid)
    response = message_error(conn.stanza.children, error, from_jid, conn.id, to_jid)
    %Conn{conn | response: response}
  end

  @doc """
  Creates a response message inside of the Router.Conn struct (response).
  This is indeed not a response but a way to simplify the send to a message
  to who was sending us something.

  Examples:
    iex> payload = [Exampple.Xml.Xmlel.new("body", %{}, ["hello world!"])]
    iex> attrs = %{"from" => "alice@example.com", "to" => "bob@example.com", "id" => "1", "type" => "chat"}
    iex> message = Exampple.Xml.Xmlel.new("message", attrs, payload)
    iex> conn = Exampple.Router.build_conn(message)
    iex> |> Exampple.Xmpp.Stanza.message_resp([])
    iex> conn.response
    "<message from=\\"alice@example.com\\" id=\\"1\\" to=\\"bob@example.com\\" type=\\"chat\\"/>"
  """
  def message_resp(%Conn{} = conn, payload) do
    from_jid = to_string(conn.from_jid)
    to_jid = to_string(conn.to_jid)
    response = message(payload, from_jid, conn.id, to_jid, conn.type)
    %Conn{conn | response: response}
  end

  @doc """
  Taking an IQ stanza, it generates a response swapping from and to and
  changing the type to "result".

  Examples:
    iex> attrs = %{"from" => "alice@example.com", "to" => "bob@example.com", "id" => "1", "type" => "get"}
    iex> payload = Exampple.Xml.Xmlel.new("query", %{"xmlns" => "jabber:iq:roster"})
    iex> xmlel = Exampple.Xml.Xmlel.new("iq", attrs, [payload])
    iex> Exampple.Xmpp.Stanza.iq_resp(xmlel)
    "<iq from=\\"bob@example.com\\" id=\\"1\\" to=\\"alice@example.com\\" type=\\"result\\"><query xmlns=\\"jabber:iq:roster\\"/></iq>"
  """
  def iq_resp(xmlel_or_conn, payload \\ nil)

  def iq_resp(%Xmlel{name: "iq", children: payload} = xmlel, nil) do
    get = &Xmlel.get_attr(xmlel, &1)
    iq(payload, get.("to"), get.("id"), get.("from"), "result")
  end

  @doc """
  Taking an IQ stanza, it generates a response swapping from and to,
  changing the type to "result" and replacing payload using the
  provided as second parameter.

  Examples:
    iex> attrs = %{"from" => "alice@example.com", "to" => "bob@example.com", "id" => "1", "type" => "get"}
    iex> payload = Exampple.Xml.Xmlel.new("query", %{"xmlns" => "jabber:iq:roster"})
    iex> xmlel = Exampple.Xml.Xmlel.new("iq", attrs, [payload])
    iex> data = Exampple.Xml.Xmlel.new("item", %{"id" => "1"}, ["contact 1"])
    iex> payload_resp = Exampple.Xml.Xmlel.new("query", %{"xmlns" => "jabber:iq:roster"})
    iex> Exampple.Xmpp.Stanza.iq_resp(xmlel, [payload_resp])
    "<iq from=\\"bob@example.com\\" id=\\"1\\" to=\\"alice@example.com\\" type=\\"result\\"><query xmlns=\\"jabber:iq:roster\\"/></iq>"
  """
  def iq_resp(%Xmlel{name: "iq"} = xmlel, payload) do
    get = &Xmlel.get_attr(xmlel, &1)
    iq(payload, get.("to"), get.("id"), get.("from"), "result")
  end

  @doc """
  Generates a result IQ stanza keeping the Router.Conn flow. It stores the response
  inside of the Router.Conn to let it perform the send from there.

  Examples:
    iex> attrs = %{
    iex>   "from" => "bob@example.com",
    iex>   "to" => "alice@example.com",
    iex>   "id" => "1"
    iex> }
    iex> payload = Exampple.Xml.Xmlel.new("query", %{"xmlns" => "jabber:iq:roster"})
    iex> iq = Exampple.Xml.Xmlel.new("iq", attrs, [payload])
    iex> conn = Exampple.Router.build_conn(iq)
    iex> |> Exampple.Xmpp.Stanza.iq_resp()
    iex> conn.response
    "<iq from=\\"bob@example.com\\" id=\\"1\\" to=\\"alice@example.com\\" type=\\"result\\"><query xmlns=\\"jabber:iq:roster\\"/></iq>"

    iex> attrs = %{
    iex>   "from" => "bob@example.com",
    iex>   "to" => "alice@example.com",
    iex>   "id" => "1"
    iex> }
    iex> payload = Exampple.Xml.Xmlel.new("query", %{"xmlns" => "jabber:iq:roster"})
    iex> iq = Exampple.Xml.Xmlel.new("iq", attrs, [payload])
    iex> conn = Exampple.Router.build_conn(iq)
    iex> |> Exampple.Xmpp.Stanza.iq_resp([])
    iex> conn.response
    "<iq from=\\"bob@example.com\\" id=\\"1\\" to=\\"alice@example.com\\" type=\\"result\\"/>"
  """
  def iq_resp(%Conn{} = conn, payload) do
    from_jid = to_string(conn.from_jid)
    to_jid = to_string(conn.to_jid)

    response =
      if payload do
        iq_resp(payload, from_jid, conn.id, to_jid)
      else
        iq_resp(conn.stanza.children, from_jid, conn.id, to_jid)
      end

    %Conn{conn | response: response}
  end

  @doc """
  Generates a result IQ stanza passing the payload, from JID, id and to JID.

  Examples:
    iex> from = "bob@example.com"
    iex> to = "alice@example.com"
    iex> id = "1"
    iex> payload = Exampple.Xml.Xmlel.new("query", %{"xmlns" => "jabber:iq:roster"})
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
    iex> payload = Exampple.Xml.Xmlel.new("query", %{"xmlns" => "jabber:iq:roster"})
    iex> xmlel = Exampple.Xml.Xmlel.new("iq", attrs, [payload])
    iex> Exampple.Xmpp.Stanza.iq_error(xmlel, "item-not-found")
    "<iq from=\\"bob@example.com\\" id=\\"1\\" to=\\"alice@example.com\\" type=\\"error\\"><query xmlns=\\"jabber:iq:roster\\"/><error code=\\"404\\" type=\\"cancel\\"><item-not-found xmlns=\\"urn:ietf:params:xml:ns:xmpp-stanzas\\"/></error></iq>"
  """
  def iq_error(%Xmlel{name: "iq", children: payload} = xmlel, error) do
    get = &Xmlel.get_attr(xmlel, &1)
    payload = payload ++ [error_tag(error)]
    iq(payload, get.("to"), get.("id"), get.("from"), "error")
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
    iex> payload = Exampple.Xml.Xmlel.new("query", %{"xmlns" => "jabber:iq:roster"})
    iex> xmlel = Exampple.Xml.Xmlel.new("iq", attrs, [payload])
    iex> conn = Exampple.Router.build_conn(xmlel)
    iex> |> Exampple.Xmpp.Stanza.iq_error("item-not-found")
    iex> conn.response
    "<iq from=\\"bob@example.com\\" id=\\"1\\" to=\\"alice@example.com\\" type=\\"error\\"><query xmlns=\\"jabber:iq:roster\\"/><error code=\\"404\\" type=\\"cancel\\"><item-not-found xmlns=\\"urn:ietf:params:xml:ns:xmpp-stanzas\\"/></error></iq>"
  """
  def iq_error(%Conn{} = conn, error) do
    to_jid = to_string(conn.to_jid)
    from_jid = to_string(conn.from_jid)
    payload = conn.stanza.children ++ [error_tag(error)]
    response = iq(payload, to_jid, conn.id, from_jid, "error")
    %Conn{conn | response: response}
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
    iex> payload = Exampple.Xml.Xmlel.new("query", %{"xmlns" => "jabber:iq:roster"})
    iex> Exampple.Xmpp.Stanza.iq_error([payload], "item-not-found", from, id, to)
    "<iq from=\\"bob@example.com\\" id=\\"1\\" to=\\"alice@example.com\\" type=\\"error\\"><query xmlns=\\"jabber:iq:roster\\"/><error code=\\"404\\" type=\\"cancel\\"><item-not-found xmlns=\\"urn:ietf:params:xml:ns:xmpp-stanzas\\"/></error></iq>"
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
    "<error code=\\"404\\" type=\\"cancel\\"><item-not-found xmlns=\\"urn:ietf:params:xml:ns:xmpp-stanzas\\"/></error>"
  """
  def error_tag(error) do
    {code, type} = get_error(error)
    err_tag = Xmlel.new(error, %{"xmlns" => @xmpp_stanzas})
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

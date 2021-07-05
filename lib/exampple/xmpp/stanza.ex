defmodule Exampple.Xmpp.Stanza do
  @moduledoc """
  Provides functions to create stanzas.
  """
  alias Exampple.Xml.Xmlel
  alias Exampple.Xmpp
  alias Exampple.Router.Conn

  @xmpp_stanzas "urn:ietf:params:xml:ns:xmpp-stanzas"

  @callback render(map()) :: Xmlel.t()

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
  Creates IQ stanzas based on the information provided by the parameters:
  the `payload` gives the content as a list of strings and/or
  `Exampple.Xml.Xmlel` structs, the `from` and `to` parameters configures
  who send and receive the message, respectively, as bare or full JID in
  string format. The `id` provides the ID for the stanza. Finally, the
  `type` provides the type for the stanza depending on if it's message,
  presence or iq the content of type could be different. Usually for normal
  chat messages the type is _chat_, for normal IQ requests is _get_ and for
  presences indicating the user is available, it's _available_.

  Check the [RFC-6121](https://tools.ietf.org/html/rfc6121) in the sections
  4.7.1 for presence, 5.2.2 for message and 6 for IQs.

  Examples:
      iex> payload = [Exampple.Xml.Xmlel.new("query", %{"xmlns" => "jabber:iq:roster"})]
      iex> alice = "alice@example.com"
      iex> bob = "bob@example.com"
      iex> Exampple.Xmpp.Stanza.iq(payload, alice, "1", bob, "get")
      iex> |> to_string()
      "<iq from=\\"alice@example.com\\" id=\\"1\\" to=\\"bob@example.com\\" type=\\"get\\"><query xmlns=\\"jabber:iq:roster\\"/></iq>"
  """
  def iq(payload, from, nil, to, type) do
    if Application.get_env(:exampple, :auto_generate_id, false) do
      iq(payload, from, gen_uuid(), to, type)
    else
      raise ArgumentError, message: "iq stanzas must have an id defined"
    end
  end

  def iq(payload, from, id, to, type) do
    stanza(payload, "iq", from, id, to, type)
  end

  @doc """
  Creates message stanzas passing the `payload`, `from` JID, `id`, `to` JID,
  and optionally the `type`.

  Examples:
      iex> payload = [Exampple.Xml.Xmlel.new("body", %{}, ["hello world!"])]
      iex> alice = "alice@example.com"
      iex> bob = "bob@example.com"
      iex> Exampple.Xmpp.Stanza.message(payload, alice, "1", bob, "chat")
      iex> |> to_string()
      "<message from=\\"alice@example.com\\" id=\\"1\\" to=\\"bob@example.com\\" type=\\"chat\\"><body>hello world!</body></message>"

      iex> payload = [Exampple.Xml.Xmlel.new("composing")]
      iex> alice = "alice@example.com"
      iex> bob = "bob@example.com"
      iex> Exampple.Xmpp.Stanza.message(payload, alice, "1", bob)
      iex> |> to_string()
      "<message from=\\"alice@example.com\\" id=\\"1\\" to=\\"bob@example.com\\"><composing/></message>"
  """
  def message(payload, from, id, to, type \\ nil) do
    id = maybe_gen_id(id, type)
    stanza(payload, "message", from, id, to, type)
  end

  @doc """
  Creates presence stanzas based on the `payload`, `from` JID, `id`,
  `to` JID, and optionally the `type` passed as parameters.

  Examples:
      iex> alice = "alice@example.com"
      iex> Exampple.Xmpp.Stanza.presence([], alice)
      iex> |> to_string()
      "<presence from=\\"alice@example.com\\"/>"
  """
  def presence(payload, from, id \\ nil, to \\ nil, type \\ nil) do
    id = maybe_gen_id(id, type)
    stanza(payload, "presence", from, id, to, type)
  end

  @doc """
  Creates error presence stanzas based on the `payload`, `error`, `from` JID,
  `id` and `to` JID passed as parameters.

  Examples:
      iex> payload = [Exampple.Xml.Xmlel.new("status", %{}, ["away"])]
      iex> alice = "alice@example.com"
      iex> bob = "bob@example.com"
      iex> Exampple.Xmpp.Stanza.presence_error(payload, "item-not-found", alice, nil, bob)
      iex> |> to_string()
      "<presence from=\\"alice@example.com\\" to=\\"bob@example.com\\" type=\\"error\\"><status>away</status><error type=\\"cancel\\"><item-not-found xmlns=\\"urn:ietf:params:xml:ns:xmpp-stanzas\\"/></error></presence>"
  """
  def presence_error(payload, error, from, id, to) do
    presence(payload ++ [error_tag(error)], from, id, to, "error")
  end

  @doc """
  Creates a response error presence (indicated `error` as second parameter)
  inside of the Exampple.Router.Conn struct (response) or sending back
  directly the XML struct if Exampple.Xml.Xmlel is used. It is depending
  on the first parameter `xmlel` or `conn`.

  Examples:
      iex> payload = [Exampple.Xml.Xmlel.new("status", %{}, ["away"])]
      iex> attrs = %{"from" => "alice@example.com", "to" => "bob@example.com"}
      iex> presence = Exampple.Xml.Xmlel.new("presence", attrs, payload)
      iex> conn = Exampple.Router.Conn.new(presence)
      iex> |> Exampple.Xmpp.Stanza.presence_error("item-not-found")
      iex> conn.response
      iex> |> to_string()
      "<presence from=\\"alice@example.com\\" to=\\"bob@example.com\\" type=\\"error\\"><status>away</status><error type=\\"cancel\\"><item-not-found xmlns=\\"urn:ietf:params:xml:ns:xmpp-stanzas\\"/></error></presence>"

      iex> payload = [Exampple.Xml.Xmlel.new("status", %{}, ["away"])]
      iex> attrs = %{"from" => "alice@example.com", "to" => "bob@example.com"}
      iex> Exampple.Xml.Xmlel.new("presence", attrs, payload)
      iex> |> Exampple.Xmpp.Stanza.presence_error("item-not-found")
      iex> |> to_string()
      "<presence from=\\"alice@example.com\\" to=\\"bob@example.com\\" type=\\"error\\"><status>away</status><error type=\\"cancel\\"><item-not-found xmlns=\\"urn:ietf:params:xml:ns:xmpp-stanzas\\"/></error></presence>"
  """
  def presence_error(%Conn{} = conn, error) do
    from_jid = to_string(conn.from_jid)
    to_jid = to_string(conn.to_jid)
    response = presence_error(conn.stanza.children, error, from_jid, conn.id, to_jid)
    %Conn{conn | response: response}
  end

  def presence_error(%Xmlel{attrs: attrs, children: children}, error) do
    from_jid = attrs["from"]
    to_jid = attrs["to"]
    id = attrs["id"]
    presence_error(children, error, from_jid, id, to_jid)
  end

  @doc """
  Creates error message stanzas based on the `payload`, `error`, `from` JID,
  `id` and `to` JID passed as parameters.

  Examples:
      iex> payload = [Exampple.Xml.Xmlel.new("body", %{}, ["hello world!"])]
      iex> alice = "alice@example.com"
      iex> bob = "bob@example.com"
      iex> Exampple.Xmpp.Stanza.message_error(payload, "item-not-found", alice, "1", bob)
      iex> |> to_string()
      "<message from=\\"alice@example.com\\" id=\\"1\\" to=\\"bob@example.com\\" type=\\"error\\"><body>hello world!</body><error type=\\"cancel\\"><item-not-found xmlns=\\"urn:ietf:params:xml:ns:xmpp-stanzas\\"/></error></message>"
  """
  def message_error(payload, error, from, id, to) do
    message(payload ++ [error_tag(error)], from, id, to, "error")
  end

  @doc """
  Creates a response error message based on the `error` indicated as second
  parameter and the stanza as first parameter and in `conn` or `xmlel` format.

  Examples:
      iex> payload = [Exampple.Xml.Xmlel.new("body", %{}, ["hello world!"])]
      iex> attrs = %{"from" => "alice@example.com", "to" => "bob@example.com", "id" => "1"}
      iex> Exampple.Xml.Xmlel.new("message", attrs, payload)
      iex> |> Exampple.Xmpp.Stanza.message_error("item-not-found")
      iex> |> to_string()
      "<message from=\\"bob@example.com\\" id=\\"1\\" to=\\"alice@example.com\\" type=\\"error\\"><body>hello world!</body><error type=\\"cancel\\"><item-not-found xmlns=\\"urn:ietf:params:xml:ns:xmpp-stanzas\\"/></error></message>"

      iex> payload = [Exampple.Xml.Xmlel.new("body", %{}, ["hello world!"])]
      iex> attrs = %{"from" => "alice@example.com", "to" => "bob@example.com", "id" => "1"}
      iex> message = Exampple.Xml.Xmlel.new("message", attrs, payload)
      iex> conn = Exampple.Router.Conn.new(message)
      iex> |> Exampple.Xmpp.Stanza.message_error("item-not-found")
      iex> conn.response
      iex> |> to_string()
      "<message from=\\"bob@example.com\\" id=\\"1\\" to=\\"alice@example.com\\" type=\\"error\\"><body>hello world!</body><error type=\\"cancel\\"><item-not-found xmlns=\\"urn:ietf:params:xml:ns:xmpp-stanzas\\"/></error></message>"
  """
  def message_error(%Xmlel{attrs: attrs, children: children}, error) do
    from_jid = attrs["to"]
    to_jid = attrs["from"]
    id = attrs["id"]
    message_error(children, error, from_jid, id, to_jid)
  end

  def message_error(%Conn{} = conn, error) do
    from_jid = to_string(conn.to_jid)
    to_jid = to_string(conn.from_jid)
    response = message_error(conn.stanza.children, error, from_jid, conn.id, to_jid)
    %Conn{conn | response: response}
  end

  @doc """
  Creates a response message inside of the Router.Conn struct (response).
  This is indeed not a response but a way to simplify the send to a message
  to who was sending us something. We are providing a `payload` as second
  parameter for the response and `conn` as the first parameter.

  Examples:
      iex> payload = [Exampple.Xml.Xmlel.new("body", %{}, ["hello world!"])]
      iex> attrs = %{"from" => "alice@example.com", "to" => "bob@example.com", "id" => "1", "type" => "chat"}
      iex> message = Exampple.Xml.Xmlel.new("message", attrs, payload)
      iex> conn = Exampple.Router.Conn.new(message)
      iex> |> Exampple.Xmpp.Stanza.message_resp([])
      iex> conn.response
      iex> |> to_string()
      "<message from=\\"bob@example.com\\" id=\\"1\\" to=\\"alice@example.com\\" type=\\"chat\\"/>"
  """
  def message_resp(%Conn{} = conn, payload) do
    from_jid = to_string(conn.from_jid)
    to_jid = to_string(conn.to_jid)
    response = message(payload, to_jid, conn.id, from_jid, conn.type)
    %Conn{conn | response: response}
  end

  @doc """
  Taking an IQ stanza, it generates a response swapping from and to and
  changing the type to "result". If a `payload` is provided (not nil) it
  will replace the payload using the second parameter.

  If the first paramenter (`xmlel_or_conn`) is a `Router.Conn` it keeps
  the flow. Stores the response inside of the `Router.Conn` and return it.

  Examples:
      iex> attrs = %{"from" => "alice@example.com", "to" => "bob@example.com", "id" => "1", "type" => "get"}
      iex> payload = Exampple.Xml.Xmlel.new("query", %{"xmlns" => "jabber:iq:roster"})
      iex> xmlel = Exampple.Xml.Xmlel.new("iq", attrs, [payload])
      iex> Exampple.Xmpp.Stanza.iq_resp(xmlel)
      iex> |> to_string()
      "<iq from=\\"bob@example.com\\" id=\\"1\\" to=\\"alice@example.com\\" type=\\"result\\"><query xmlns=\\"jabber:iq:roster\\"/></iq>"

      iex> attrs = %{"from" => "alice@example.com", "to" => "bob@example.com", "id" => "1", "type" => "get"}
      iex> payload = Exampple.Xml.Xmlel.new("query", %{"xmlns" => "jabber:iq:roster"})
      iex> xmlel = Exampple.Xml.Xmlel.new("iq", attrs, [payload])
      iex> Exampple.Xml.Xmlel.new("item", %{"id" => "1"}, ["contact 1"])
      iex> payload_resp = Exampple.Xml.Xmlel.new("query", %{"xmlns" => "jabber:iq:roster"})
      iex> Exampple.Xmpp.Stanza.iq_resp(xmlel, [payload_resp])
      iex> |> to_string()
      "<iq from=\\"bob@example.com\\" id=\\"1\\" to=\\"alice@example.com\\" type=\\"result\\"><query xmlns=\\"jabber:iq:roster\\"/></iq>"

      iex> attrs = %{
      iex>   "from" => "alice@example.com",
      iex>   "to" => "bob@example.com",
      iex>   "id" => "1"
      iex> }
      iex> payload = Exampple.Xml.Xmlel.new("query", %{"xmlns" => "jabber:iq:roster"})
      iex> iq = Exampple.Xml.Xmlel.new("iq", attrs, [payload])
      iex> conn = Exampple.Router.Conn.new(iq)
      iex> |> Exampple.Xmpp.Stanza.iq_resp()
      iex> conn.response
      iex> |> to_string()
      "<iq from=\\"bob@example.com\\" id=\\"1\\" to=\\"alice@example.com\\" type=\\"result\\"><query xmlns=\\"jabber:iq:roster\\"/></iq>"

      iex> attrs = %{
      iex>   "from" => "alice@example.com",
      iex>   "to" => "bob@example.com",
      iex>   "id" => "1"
      iex> }
      iex> payload = Exampple.Xml.Xmlel.new("query", %{"xmlns" => "jabber:iq:roster"})
      iex> iq = Exampple.Xml.Xmlel.new("iq", attrs, [payload])
      iex> conn = Exampple.Router.Conn.new(iq)
      iex> |> Exampple.Xmpp.Stanza.iq_resp([])
      iex> conn.response
      iex> |> to_string()
      "<iq from=\\"bob@example.com\\" id=\\"1\\" to=\\"alice@example.com\\" type=\\"result\\"/>"
  """
  def iq_resp(xmlel_or_conn, payload \\ nil)

  def iq_resp(%Xmlel{name: "iq", children: payload} = xmlel, nil) do
    get = &Xmlel.get_attr(xmlel, &1)
    iq_resp(payload, get.("to"), get.("id"), get.("from"))
  end

  def iq_resp(%Xmlel{name: "iq"} = xmlel, payload) do
    get = &Xmlel.get_attr(xmlel, &1)
    iq_resp(payload, get.("to"), get.("id"), get.("from"))
  end

  def iq_resp(%Conn{} = conn, payload) do
    from_jid = to_string(conn.from_jid)
    to_jid = to_string(conn.to_jid)

    response =
      if payload do
        iq_resp(payload, to_jid, conn.id, from_jid)
      else
        iq_resp(conn.stanza.children, to_jid, conn.id, from_jid)
      end

    %Conn{conn | response: response}
  end

  @doc """
  Generates a result IQ stanza passing the `payload`, `from` JID, `id` and `to` JID.

  Examples:
      iex> from = "bob@example.com"
      iex> to = "alice@example.com"
      iex> id = "1"
      iex> payload = Exampple.Xml.Xmlel.new("query", %{"xmlns" => "jabber:iq:roster"})
      iex> Exampple.Xmpp.Stanza.iq_resp([payload], from, id, to)
      iex> |> to_string()
      "<iq from=\\"bob@example.com\\" id=\\"1\\" to=\\"alice@example.com\\" type=\\"result\\"><query xmlns=\\"jabber:iq:roster\\"/></iq>"

      iex> from = "bob@example.com"
      iex> to = "alice@example.com"
      iex> id = "1"
      iex> Exampple.Xmpp.Stanza.iq_resp(from, id, to)
      iex> |> to_string()
      "<iq from=\\"bob@example.com\\" id=\\"1\\" to=\\"alice@example.com\\" type=\\"result\\"/>"
  """
  def iq_resp(payload \\ [], from, id, to) do
    iq(payload, from, id, to, "result")
  end

  @doc """
  Taken an IQ stanza (`xmlel`), it generates an error based on `error`
  parameter. The codes available are the following ones:

  - bad-request
  - forbidden
  - item-not-found
  - not-acceptable
  - internal-server-error
  - service-unavailable
  - feature-not-implemented

  see more here: https://xmpp.org/extensions/xep-0086.html

  You can also use a 3-elements tuple to send {error, lang, text}, this way you can create a rich
  error like this:

  ```xml
  <error type="cancel">
    <item-not-found xmlns="urn:ietf:params:xml:ns:xmpp-stanzas"/>
    <text lang="en" xmlns="urn:ietf:params:xml:ns:xmpp-stanzas">item was not found in database</text>
  </error>
  ```

  Examples:
      iex> attrs = %{"from" => "alice@example.com", "to" => "bob@example.com", "id" => "1", "type" => "get"}
      iex> payload = Exampple.Xml.Xmlel.new("query", %{"xmlns" => "jabber:iq:roster"})
      iex> xmlel = Exampple.Xml.Xmlel.new("iq", attrs, [payload])
      iex> Exampple.Xmpp.Stanza.iq_error(xmlel, "item-not-found")
      iex> |> to_string()
      "<iq from=\\"bob@example.com\\" id=\\"1\\" to=\\"alice@example.com\\" type=\\"error\\"><query xmlns=\\"jabber:iq:roster\\"/><error type=\\"cancel\\"><item-not-found xmlns=\\"urn:ietf:params:xml:ns:xmpp-stanzas\\"/></error></iq>"

      iex> attrs = %{"from" => "alice@example.com", "to" => "bob@example.com", "id" => "1", "type" => "get"}
      iex> payload = Exampple.Xml.Xmlel.new("query", %{"xmlns" => "jabber:iq:roster"})
      iex> xmlel = Exampple.Xml.Xmlel.new("iq", attrs, [payload])
      iex> conn = Exampple.Router.Conn.new(xmlel)
      iex> |> Exampple.Xmpp.Stanza.iq_error("item-not-found")
      iex> conn.response
      iex> |> to_string()
      "<iq from=\\"bob@example.com\\" id=\\"1\\" to=\\"alice@example.com\\" type=\\"error\\"><query xmlns=\\"jabber:iq:roster\\"/><error type=\\"cancel\\"><item-not-found xmlns=\\"urn:ietf:params:xml:ns:xmpp-stanzas\\"/></error></iq>"
  """
  def iq_error(%Xmlel{name: "iq", children: payload} = xmlel, error) do
    get = &Xmlel.get_attr(xmlel, &1)
    payload = payload ++ [error_tag(error)]
    iq(payload, get.("to"), get.("id"), get.("from"), "error")
  end

  def iq_error(%Conn{} = conn, error) do
    to_jid = to_string(conn.to_jid)
    from_jid = to_string(conn.from_jid)
    payload = conn.stanza.children ++ [error_tag(error)]
    response = iq(payload, to_jid, conn.id, from_jid, "error")
    %Conn{conn | response: response}
  end

  @doc """
  Generates an error IQ stanza passing the `payload`, `from` JID, `id` and
  `to` JID. The codes available are the following ones:

  - bad-request
  - forbidden
  - item-not-found
  - not-acceptable
  - internal-server-error
  - service-unavailable
  - feature-not-implemented

  see more here: https://xmpp.org/extensions/xep-0086.html

  You can also use a 3-elements tuple to send {error, lang, text}, this way you can create a rich
  error like this:

  ```xml
  <error type="cancel">
    <item-not-found xmlns="urn:ietf:params:xml:ns:xmpp-stanzas"/>
    <text lang="en" xmlns="urn:ietf:params:xml:ns:xmpp-stanzas">item was not found in database</text>
  </error>
  ```

  Examples:
      iex> from = "bob@example.com"
      iex> to = "alice@example.com"
      iex> id = "1"
      iex> payload = Exampple.Xml.Xmlel.new("query", %{"xmlns" => "jabber:iq:roster"})
      iex> Exampple.Xmpp.Stanza.iq_error([payload], "item-not-found", from, id, to)
      iex> |> to_string()
      "<iq from=\\"bob@example.com\\" id=\\"1\\" to=\\"alice@example.com\\" type=\\"error\\"><query xmlns=\\"jabber:iq:roster\\"/><error type=\\"cancel\\"><item-not-found xmlns=\\"urn:ietf:params:xml:ns:xmpp-stanzas\\"/></error></iq>"
  """
  def iq_error(payload, error, from, id, to) do
    iq(payload ++ [error_tag(error)], from, id, to, "error")
  end

  @doc """
  Returns an error tag based on the `error` provided as parameter.
  The codes available are the following ones:

  - bad-request
  - forbidden
  - item-not-found
  - not-acceptable
  - internal-server-error
  - service-unavailable
  - feature-not-implemented

  see more here: https://xmpp.org/extensions/xep-0086.html

  You can also use a tuple ({error, lang, text} or {error, lang, text, custom_tag}), this way you
  can create a rich error like this:

  ```xml
  <error type="cancel">
    <item-not-found xmlns="urn:ietf:params:xml:ns:xmpp-stanzas"/>
    <text lang="en" xmlns="urn:ietf:params:xml:ns:xmpp-stanzas">item was not found in database</text>
  </error>
  ```

  Examples:
      iex> Exampple.Xmpp.Stanza.error_tag("item-not-found") |> to_string()
      "<error type=\\"cancel\\"><item-not-found xmlns=\\"urn:ietf:params:xml:ns:xmpp-stanzas\\"/></error>"
      iex> Exampple.Xmpp.Stanza.error_tag({"item-not-found", "en", "item was not found in database"}) |> to_string()
      "<error type=\\"cancel\\"><item-not-found xmlns=\\"urn:ietf:params:xml:ns:xmpp-stanzas\\"/><text lang=\\"en\\" xmlns=\\"urn:ietf:params:xml:ns:xmpp-stanzas\\">item was not found in database</text></error>"
      iex> Exampple.Xmpp.Stanza.error_tag({"resource-constraint", "en", "throttled", %Exampple.Xml.Xmlel{name: "timeout", attrs: %{"seconds" => "60", "xmlel" => "urn:custom:throttle"}}}) |> to_string()
      "<error type=\\"wait\\"><resource-constraint xmlns=\\"urn:ietf:params:xml:ns:xmpp-stanzas\\"/><text lang=\\"en\\" xmlns=\\"urn:ietf:params:xml:ns:xmpp-stanzas\\">throttled</text><timeout seconds=\\"60\\" xmlel=\\"urn:custom:throttle\\"/></error>"
  """
  def error_tag(error) when is_binary(error) do
    type = Xmpp.Error.get_error(error)
    err_tag = Xmlel.new(error, %{"xmlns" => @xmpp_stanzas})
    Xmlel.new("error", %{"type" => type}, [err_tag])
  end

  def error_tag({error, lang, text}) do
    type = Xmpp.Error.get_error(error)
    err_tag = Xmlel.new(error, %{"xmlns" => @xmpp_stanzas})
    text_tag = Xmlel.new("text", %{"xmlns" => @xmpp_stanzas, "lang" => lang}, [text])
    Xmlel.new("error", %{"type" => type}, [err_tag, text_tag])
  end

  def error_tag({error, lang, text, custom_tag}) do
    type = Xmpp.Error.get_error(error)
    err_tag = Xmlel.new(error, %{"xmlns" => @xmpp_stanzas})
    text_tag = Xmlel.new("text", %{"xmlns" => @xmpp_stanzas, "lang" => lang}, [text])
    Xmlel.new("error", %{"type" => type}, [err_tag, text_tag, custom_tag])
  end

  defp maybe_add(attrs, _name, nil), do: attrs
  defp maybe_add(attrs, _name, ""), do: attrs
  defp maybe_add(attrs, name, value), do: Map.put(attrs, name, value)

  defp maybe_gen_id(nil, "error"), do: nil

  defp maybe_gen_id(nil, _type) do
    if Application.get_env(:exampple, :auto_generate_id, false) do
      gen_uuid()
    end
  end

  defp maybe_gen_id(id, _type), do: id

  @doc """
  Gen ID let us to generate an ID based on UUID v4.
  """
  if Mix.env() == :test do
    def gen_uuid() do
      Application.get_env(:exampple, :gen_uuid, "5dc7ff90-60ea-462c-9d71-581487afdb71")
    end
  else
    def gen_uuid(), do: UUID.uuid4()
  end

  @doc """
  Generates an stanza passed the stanza type (iq, presence or message), the `from`
  and `to` for sender and recipient respectively, the `id` for the stanza, the
  `type` which depends on the stanza type it could be set, get or result for iq,
  available, unavailable, probe, subscribe, subscribed, ... for presence or
  chat, groupchat, normal or head for message. And we set also the `payload` as
  a list of elements to be included inside of the stanza.

  Examples:
      iex> Exampple.Xmpp.Stanza.stanza([], "presence", nil, nil, nil, nil)
      iex> |> to_string()
      "<presence/>"
  """
  def stanza(payload, stanza_type, from, id, to, type) do
    attrs =
      %{}
      |> maybe_add("id", id)
      |> maybe_add("from", from)
      |> maybe_add("to", to)
      |> maybe_add("type", type)

    Xmlel.new(stanza_type, attrs, payload)
  end

  @doc """
  Agnostic to the type of stanza it generates an `error` (provided as second
  parameter) for the incoming stanza (provided as first parameter as `xmlel` or
  `conn`).

  The supported types are: iq, presence and message.

  Examples:
      iex> Exampple.Xmpp.Stanza.stanza([], "presence", nil, nil, nil, nil)
      iex> |> Exampple.Xmpp.Stanza.error("forbidden")
      iex> |> to_string()
      "<presence type=\\"error\\"><error type=\\"auth\\"><forbidden xmlns=\\"urn:ietf:params:xml:ns:xmpp-stanzas\\"/></error></presence>"

      iex> Exampple.Xmpp.Stanza.stanza([], "message", nil, nil, nil, nil)
      iex> |> Exampple.Xmpp.Stanza.error("forbidden")
      iex> |> to_string()
      "<message type=\\"error\\"><error type=\\"auth\\"><forbidden xmlns=\\"urn:ietf:params:xml:ns:xmpp-stanzas\\"/></error></message>"

      iex> Exampple.Xmpp.Stanza.stanza([], "iq", nil, "42", nil, nil)
      iex> |> Exampple.Xmpp.Stanza.error("forbidden")
      iex> |> to_string()
      "<iq id=\\"42\\" type=\\"error\\"><error type=\\"auth\\"><forbidden xmlns=\\"urn:ietf:params:xml:ns:xmpp-stanzas\\"/></error></iq>"
  """
  def error(%Xmlel{name: "iq"} = xmlel, error), do: iq_error(xmlel, error)
  def error(%Xmlel{name: "message"} = xmlel, error), do: message_error(xmlel, error)
  def error(%Xmlel{name: "presence"} = xmlel, error), do: presence_error(xmlel, error)

  def error(%Conn{stanza_type: "iq"} = conn, error), do: iq_error(conn, error)
  def error(%Conn{stanza_type: "message"} = conn, error), do: message_error(conn, error)
  def error(%Conn{stanza_type: "presence"} = conn, error), do: presence_error(conn, error)
end

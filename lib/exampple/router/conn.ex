defmodule Exampple.Router.Conn do
  @moduledoc """
  Conn is a module to store the information related to a XMPP
  request. Conn has the following information inside:

  - `domain`: the component domain.
  - `from_jid`: the JID where the stanza is coming from.
  - `to_jid`: the JID where the stanza is sent to.
  - `id`: the ID for the stanza.
  - `type`: the type attribute of the stanza. Depending on the stanza
    type it could be `chat`, `groupchat`, `normal`, `get`, `set`, ...
  - `xmlns`: the namespace for the XML stanza.
  - `stanza_type`: the stanza type, it could be `iq`, `message` or
    `presence`. It is possible to receive other kind of XML stanzas,
    but it is not common.
  - `stanza`: the original stanza in `%Xmlel{}` format.
  - `reponse`: the generated response in use if we pass the connection
    to the `Exampple.Component` module.
  - `envelope`: it is a closure needed if we are receiving stanzas
    which are using an envelope. It is not needed to handle it manually,
    see further information about this in `Exampple.Router`.
  """
  alias Exampple.Router.Conn
  alias Exampple.Xml.Xmlel
  alias Exampple.Xmpp.Jid

  defstruct domain: nil,
            from_jid: nil,
            to_jid: nil,
            id: nil,
            type: nil,
            xmlns: "",
            stanza_type: nil,
            stanza: nil,
            response: nil,
            envelope: nil

  @type t() :: %__MODULE__{}

  @doc """
  Creates a new connection passing a `%Xmlel{}` struct in `xmlel` as the
  first parameter and a `domain` as a second parameter (or `nil` by default)
  to create a `%Conn{}` struct.
  """
  def new(%Xmlel{} = xmlel, domain \\ nil) do
    xmlns =
      case xmlel.children do
        [%Xmlel{} = subel | _] -> Xmlel.get_attr(subel, "xmlns", "")
        _ -> ""
      end

    %Conn{
      domain: domain,
      from_jid: Jid.parse(Xmlel.get_attr(xmlel, "from")),
      to_jid: Jid.parse(Xmlel.get_attr(xmlel, "to")),
      id: Xmlel.get_attr(xmlel, "id"),
      type:
        case xmlel.name do
          "message" -> Xmlel.get_attr(xmlel, "type", "normal")
          "presence" -> Xmlel.get_attr(xmlel, "type", "available")
          _ -> Xmlel.get_attr(xmlel, "type", "")
        end,
      xmlns: xmlns,
      stanza_type: xmlel.name,
      stanza: xmlel
    }
  end

  @doc """
  Obtains the response stored inside of the `conn`. Checking if there
  is an envelope used or not.
  """
  def get_response(%Conn{envelope: nil, response: response}) when response != nil do
    to_string(response)
  end

  def get_response(%Conn{envelope: envelope, response: response}) when response != nil do
    get_response(envelope.(response))
  end
end

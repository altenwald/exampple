defmodule Exampple.Router.Conn do
  @moduledoc false
  alias Exampple.Router.Conn
  alias Exampple.Xml.Xmlel
  alias Exampple.Xmpp.Jid

  defstruct domain: nil,
            from_jid: nil,
            to_jid: nil,
            id: nil,
            type: nil,
            xmlns: nil,
            stanza_type: nil,
            stanza: nil,
            response: nil,
            envelope: nil

  @type t() :: %__MODULE__{}

  def new(%Xmlel{} = xmlel, domain \\ nil) do
    xmlns =
      case xmlel.children do
        [%Xmlel{} = subel | _] -> Xmlel.get_attr(subel, "xmlns")
        _ -> nil
      end

    %Conn{
      domain: domain,
      from_jid: Jid.parse(Xmlel.get_attr(xmlel, "from")),
      to_jid: Jid.parse(Xmlel.get_attr(xmlel, "to")),
      id: Xmlel.get_attr(xmlel, "id"),
      type: Xmlel.get_attr(xmlel, "type", "normal"),
      xmlns: xmlns,
      stanza_type: xmlel.name,
      stanza: xmlel
    }
  end

  def get_response(%Conn{envelope: nil, response: response}) when response != nil do
    to_string(response)
  end
  def get_response(%Conn{envelope: envelope, response: response}) when response != nil do
    get_response(envelope.(response))
  end
end

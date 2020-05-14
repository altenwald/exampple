defmodule Exampple.Xmpp.Envelope do
  alias Exampple.Router.Conn
  alias Exampple.Xml.Xmlel
  alias Exampple.Xmpp.Stanza

  def handle(%Conn{stanza_type: "message"}) do
    nil
  end

  def handle(%Conn{stanza_type: "iq" = stanza_type} = conn, query) do
    base = get_when(query, stanza_type)
    envelope = fn(internal_stanza) ->
      payload = insert_when(query, stanza_type, internal_stanza)
      Stanza.iq_resp(conn, [payload])
    end
    conn =
      Conn.new(base, conn.domain)
      |> Map.put(:envelope, envelope)
    %Xmlel{children: query} = base
    {conn, query}
  end

  defp get_when([%Xmlel{name: name} = xmlel | _], name), do: xmlel
  defp get_when([%Xmlel{children: children} | _], name) do
    get_when(children, name)
  end

  defp insert_when([%Xmlel{name: name} | _], name, payload), do: payload
  defp insert_when([%Xmlel{children: children} = xmlel | _], name, payload) do
    %Xmlel{xmlel | children: [insert_when(children, name, payload)]}
  end
end

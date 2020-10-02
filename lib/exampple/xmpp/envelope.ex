defmodule Exampple.Xmpp.Envelope do
  @moduledoc """
  Envelope helps to create a function to be stored inside of the
  `Exampple.Router.Conn` which will be in use when a response will
  be processed.

  The idea of this module was based on handling the
  [Namespace delegation (XEP-0355)](https://xmpp.org/extensions/xep-0355.html)
  but also the [Stanza forwarding (XEP-0297)](https://xmpp.org/extensions/xep-0297.html).

  This way we process the stanzas wrapped using the `Exampple.Router`
  and the configuration provided by our router configuration in a
  transparent way.
  """
  alias Exampple.Router.Conn
  alias Exampple.Xml.Xmlel
  alias Exampple.Xmpp.Stanza

  @doc """
  Handle the stanza inside of a `Exampple.Router.Conn` and creates
  an envelope function with it. The function is placed inside of a
  new `Exampple.Router.Conn` parsed with the data provided from the
  internal stanza.
  """
  def handle(%Conn{stanza_type: "message"}, _query) do
    nil
  end

  def handle(%Conn{stanza_type: "iq" = stanza_type} = conn, query) do
    base = get_when(query, stanza_type)

    envelope = fn internal_stanza ->
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

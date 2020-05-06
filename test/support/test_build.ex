defmodule TestBuild do
  use Exampple.Xmpp.Stanza

  defstruct name: nil

  def render(data), do: Exampple.Xml.Xmlel.new(data.name, %{}, [])
end

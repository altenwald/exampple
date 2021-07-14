defprotocol Exampple.Xml do
  @doc """
  Transforms a data structure to Xmlel structure.
  """
  def to_xmlel(data)
end

defimpl Exampple.Xml, for: BitString do
  def to_xmlel(data) do
    data
    |> Exampple.Xml.Xmlel.parse()
    |> Exampple.Xml.Xmlel.clean_spaces()
  end
end

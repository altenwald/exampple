defmodule Exampple.Saxy.Xmlel do
  @moduledoc """
  Xmlel is a struct data which is intended to help with the parsing
  of the XML elements.
  """

  alias Exampple.Saxy.Xmlel
  alias Saxy.Encoder

  @type attr_name :: binary
  @type attr_value :: binary
  @type attrs :: %{attr_name => attr_value}

  @type t :: %__MODULE__{name: binary, attrs: attrs, children: [t]}
  @type children :: [t]

  defstruct name: nil, attrs: %{}, children: []

  @doc """
  Creates a Xmlel struct.

  Examples:
    iex> Exampple.Saxy.Xmlel.new("foo")
    %Exampple.Saxy.Xmlel{attrs: %{}, children: [], name: "foo"}

    iex> Exampple.Saxy.Xmlel.new("bar", %{"id" => "10"})
    %Exampple.Saxy.Xmlel{attrs: %{"id" => "10"}, children: [], name: "bar"}

    iex> Exampple.Saxy.Xmlel.new("bar", [{"id", "10"}])
    %Exampple.Saxy.Xmlel{attrs: %{"id" => "10"}, children: [], name: "bar"}
  """
  @spec new(name :: binary, attrs | [{attr_name, attr_value}], children) :: t
  def new(name, attrs \\ %{}, children \\ [])

  def new(name, attrs, children) when is_list(attrs) do
    new(name, Enum.into(attrs, %{}), children)
  end

  def new(name, attrs, children) when is_map(attrs) do
    %Xmlel{name: name, attrs: attrs, children: children}
  end

  @doc """
  Sigil to use ~X to provide XML text and transform it to Xmlel struct.

  Examples:
    iex> import Exampple.Saxy.Xmlel
    iex> ~X|<foo/>|
    %Exampple.Saxy.Xmlel{attrs: %{}, children: [], name: "foo"}
  """
  def sigil_X(string, _addons) do
    parse(string)
  end

  @doc """
  Parser a XML string into Xmlel struct.

  Examples:
    iex> Exampple.Saxy.Xmlel.parse("<foo/>")
    %Exampple.Saxy.Xmlel{name: "foo", attrs: %{}, children: []}

    iex> Exampple.Saxy.Xmlel.parse("<foo bar='10'>hello world!</foo>")
    %Exampple.Saxy.Xmlel{name: "foo", attrs: %{"bar" => "10"}, children: ["hello world!"]}

    iex> Exampple.Saxy.Xmlel.parse("<foo><bar>hello world!</bar></foo>")
    %Exampple.Saxy.Xmlel{name: "foo", attrs: %{}, children: [%Exampple.Saxy.Xmlel{name: "bar", attrs: %{}, children: ["hello world!"]}]}
  """
  def parse(xml) when is_binary(xml) do
    {:ok, [xmlel]} = Saxy.parse_string(xml, Exampple.Saxy.Parser.Simple, [])
    decode(xmlel)
  end

  defp decode(data) when is_binary(data), do: data

  defp decode(%Xmlel{attrs: attrs, children: children} = xmlel) do
    attrs = Enum.into(attrs, %{})
    children = Enum.map(children, &decode/1)
    %Xmlel{xmlel | attrs: attrs, children: children}
  end

  defimpl String.Chars, for: __MODULE__ do
    defp encode(%Xmlel{} = xmlel) do
      children = Enum.map(xmlel.children, &encode/1)
      {xmlel.name, Enum.into(xmlel.attrs, []), children}
    end

    defp encode(content) when is_binary(content), do: content

    @doc """
    Implements `to_string/1` to convert a XML entity to a XML
    representation.

    Examples:
      iex> Exampple.Saxy.Xmlel.new("foo") |> to_string()
      "<foo/>"

      iex> Exampple.Saxy.Xmlel.new("bar", %{"id" => "10"}) |> to_string()
      "<bar id=\\"10\\"/>"

      iex> query = Exampple.Saxy.Xmlel.new("query", %{"xmlns" => "urn:jabber:iq"})
      iex> Exampple.Saxy.Xmlel.new("iq", %{"type" => "get"}, [query]) |> to_string()
      "<iq type=\\"get\\"><query xmlns=\\"urn:jabber:iq\\"/></iq>"
    """
    def to_string(xmlel) do
      encode(xmlel)
      |> Encoder.encode_to_binary()
    end
  end

  @doc """
  Retrieve an attribute from a Xmlel struct.

  Examples:
    iex> attrs = %{"id" => "100", "name" => "Alice"}
    iex> xmlel = %Exampple.Saxy.Xmlel{attrs: attrs}
    iex> Exampple.Saxy.Xmlel.get_attr(xmlel, "name")
    "Alice"
    iex> Exampple.Saxy.Xmlel.get_attr(xmlel, "surname")
    nil
  """
  def get_attr(%Xmlel{attrs: attrs}, name, default \\ nil) do
    Map.get(attrs, name, default)
  end

  @doc """
  Deletes an attribute from a Xmlel struct.

  Examples:
    iex> attrs = %{"id" => "100", "name" => "Alice"}
    iex> xmlel = %Exampple.Saxy.Xmlel{attrs: attrs}
    iex> Exampple.Saxy.Xmlel.get_attr(xmlel, "name")
    "Alice"
    iex> Exampple.Saxy.Xmlel.delete_attr(xmlel, "name")
    iex> |> Exampple.Saxy.Xmlel.get_attr("name")
    nil
  """
  def delete_attr(%Xmlel{attrs: attrs} = xmlel, name) do
    %Xmlel{xmlel | attrs: Map.delete(attrs, name)}
  end

  @doc """
  Add or set an attribute inside of the Xmlel struct passed as
  parameter.

  Examples:
    iex> attrs = %{"id" => "100", "name" => "Alice"}
    iex> %Exampple.Saxy.Xmlel{attrs: attrs}
    iex> |> Exampple.Saxy.Xmlel.put_attr("name", "Bob")
    iex> |> Exampple.Saxy.Xmlel.get_attr("name")
    "Bob"
  """
  def put_attr(%Xmlel{attrs: attrs} = xmlel, name, value) do
    %Xmlel{xmlel | attrs: Map.put(attrs, name, value)}
  end

  @doc """
  Add or set one or several attributes inside of the Xmlel struct
  passed as parameter.

  Examples:
    iex> fields = %{"id" => "100", "name" => "Alice", "city" => "Cordoba"}
    iex> Exampple.Saxy.Xmlel.put_attrs(%Exampple.Saxy.Xmlel{name: "foo"}, fields) |> to_string()
    "<foo city=\\"Cordoba\\" id=\\"100\\" name=\\"Alice\\"/>"

    iex> fields = %{"id" => "100", "name" => "Alice", "city" => :"Cordoba"}
    iex> Exampple.Saxy.Xmlel.put_attrs(%Exampple.Saxy.Xmlel{name: "foo"}, fields) |> to_string()
    "<foo id=\\"100\\" name=\\"Alice\\"/>"
  """
  def put_attrs(xmlel, fields) do
    Enum.reduce(fields, xmlel, fn
      {_field, value}, acc when is_atom(value) -> acc
      {field, value}, acc -> put_attr(acc, field, value)
    end)
  end

  @doc """
  This function removes the extra spaces inside of the stanzas to ensure
  we can perform matching in a proper way.

  Examples:
    iex> "<foo>\\n    <bar>\\n        Hello<br/>world!\\n    </bar>\\n</foo>"
    iex> |> Exampple.Saxy.Xmlel.parse()
    iex> |> Exampple.Saxy.Xmlel.clean_spaces()
    iex> |> to_string()
    "<foo><bar>Hello<br/>world!</bar></foo>"
  """
  def clean_spaces(%Xmlel{children: []} = xmlel), do: xmlel

  def clean_spaces(%Xmlel{children: children} = xmlel) do
    children =
      Enum.reduce(children, [], fn
        content, acc when is_binary(content) ->
          content = String.trim(content)
          if content != "", do: [content | acc], else: acc

        %Xmlel{} = x, acc ->
          [clean_spaces(x) | acc]
      end)
      |> Enum.reverse()

    %Xmlel{xmlel | children: children}
  end
end

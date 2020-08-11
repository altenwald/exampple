defmodule Exampple.Xml.Xmlel do
  @moduledoc """
  Xmlel is a struct data which is intended to help with the parsing
  of the XML elements.
  """

  alias Exampple.Xml.Xmlel

  @type attr_name :: binary
  @type attr_value :: binary
  @type attrs :: %{attr_name => attr_value}

  @type t :: %__MODULE__{name: binary, attrs: attrs, children: [t | binary | struct]}
  @type children :: [t] | [String.t()]

  defstruct name: nil, attrs: %{}, children: []

  @doc """
  Creates a Xmlel struct.

  Examples:
      iex> Exampple.Xml.Xmlel.new("foo")
      %Exampple.Xml.Xmlel{attrs: %{}, children: [], name: "foo"}

      iex> Exampple.Xml.Xmlel.new("bar", %{"id" => "10"})
      %Exampple.Xml.Xmlel{attrs: %{"id" => "10"}, children: [], name: "bar"}

      iex> Exampple.Xml.Xmlel.new("bar", [{"id", "10"}])
      %Exampple.Xml.Xmlel{attrs: %{"id" => "10"}, children: [], name: "bar"}
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
      iex> import Exampple.Xml.Xmlel
      iex> ~X|<foo>
      iex> </foo>
      iex> |
      %Exampple.Xml.Xmlel{attrs: %{}, children: ["\\n "], name: "foo"}
  """
  def sigil_X(string, _addons) do
    parse(string)
  end

  @doc """
  Sigil to use ~x to provide XML text and transform it to Xmlel struct
  removing spaces and breaking lines.

  Examples:
      iex> import Exampple.Xml.Xmlel
      iex> ~x|<foo>
      iex> </foo>
      iex> |
      %Exampple.Xml.Xmlel{attrs: %{}, children: [], name: "foo"}
  """
  def sigil_x(string, _addons) do
    string
    |> parse()
    |> clean_spaces()
  end

  @doc """
  Parser a XML string into Xmlel struct.

  Examples:
      iex> Exampple.Xml.Xmlel.parse("<foo/>")
      %Exampple.Xml.Xmlel{name: "foo", attrs: %{}, children: []}

      iex> Exampple.Xml.Xmlel.parse("<foo bar='10'>hello world!</foo>")
      %Exampple.Xml.Xmlel{name: "foo", attrs: %{"bar" => "10"}, children: ["hello world!"]}

      iex> Exampple.Xml.Xmlel.parse("<foo><bar>hello world!</bar></foo>")
      %Exampple.Xml.Xmlel{name: "foo", attrs: %{}, children: [%Exampple.Xml.Xmlel{name: "bar", attrs: %{}, children: ["hello world!"]}]}
  """
  def parse(xml) when is_binary(xml) do
    {:ok, [xmlel]} = Saxy.parse_string(xml, Exampple.Xml.Parser.Simple, [])
    decode(xmlel)
  end

  @doc """
  This function is a helper function to translate the tuples coming
  from Saxy to the Xmlel structs.

  Examples:
      iex> Exampple.Xml.Xmlel.decode({"foo", [], []})
      %Exampple.Xml.Xmlel{name: "foo", attrs: %{}, children: []}

      iex> Exampple.Xml.Xmlel.decode({"bar", [{"id", "10"}], ["Hello!"]})
      %Exampple.Xml.Xmlel{name: "bar", attrs: %{"id" => "10"}, children: ["Hello!"]}
  """
  def decode(data) when is_binary(data), do: data

  def decode(%Xmlel{attrs: attrs, children: children} = xmlel) do
    children = Enum.map(children, &decode/1)
    %Xmlel{xmlel | attrs: attrs, children: children}
  end

  def decode({name, attrs, children}) do
    attrs = Enum.into(attrs, %{})
    decode(%Xmlel{name: name, attrs: attrs, children: children})
  end

  @doc """
  This function is a helper function to translate the content of the
  Xmlel structs to the tuples needed by Saxy.

  Examples:
      iex> Exampple.Xml.Xmlel.encode(%Exampple.Xml.Xmlel{name: "foo"})
      {"foo", [], []}

      iex> Exampple.Xml.Xmlel.encode(%Exampple.Xml.Xmlel{name: "bar", attrs: %{"id" => "10"}, children: ["Hello!"]})
      {"bar", [{"id", "10"}], ["Hello!"]}

      iex> Exampple.Xml.Xmlel.encode(%TestBuild{name: "bro"})
      "<bro/>"
  """
  def encode(%Xmlel{} = xmlel) do
    children = Enum.map(xmlel.children, &encode/1)
    {xmlel.name, Enum.into(xmlel.attrs, []), children}
  end

  def encode(content) when is_binary(content), do: content

  def encode(%struct_name{} = struct) do
    builder = Module.concat(Saxy.Builder, struct_name)

    struct
    |> builder.build()
    |> Saxy.encode!()
  end

  defimpl String.Chars, for: __MODULE__ do
    alias Exampple.Xml.Xmlel
    alias Saxy.Encoder
    alias Saxy.Builder

    @doc """
    Implements `to_string/1` to convert a XML entity to a XML
    representation.

    Examples:
        iex> Exampple.Xml.Xmlel.new("foo") |> to_string()
        "<foo/>"

        iex> Exampple.Xml.Xmlel.new("bar", %{"id" => "10"}) |> to_string()
        "<bar id=\\"10\\"/>"

        iex> query = Exampple.Xml.Xmlel.new("query", %{"xmlns" => "urn:jabber:iq"})
        iex> Exampple.Xml.Xmlel.new("iq", %{"type" => "get"}, [query]) |> to_string()
        "<iq type=\\"get\\"><query xmlns=\\"urn:jabber:iq\\"/></iq>"
    """
    def to_string(xmlel) do
      xmlel
      |> Xmlel.encode()
      |> Builder.build()
      |> Encoder.encode_to_binary()
    end
  end

  defimpl Saxy.Builder, for: Xmlel do
    @moduledoc false
    @doc """
    Generates the Saxy tuples from Xmlel structs.

    Examples:
        iex> Saxy.Builder.build(Exampple.Xml.Xmlel.new("foo", %{}, []))
        {"foo", [], []}
    """
    def build(xmlel) do
      Xmlel.encode(xmlel)
    end
  end

  @doc """
  Retrieve an attribute from a Xmlel struct.

  Examples:
      iex> attrs = %{"id" => "100", "name" => "Alice"}
      iex> xmlel = %Exampple.Xml.Xmlel{attrs: attrs}
      iex> Exampple.Xml.Xmlel.get_attr(xmlel, "name")
      "Alice"
      iex> Exampple.Xml.Xmlel.get_attr(xmlel, "surname")
      nil
  """
  def get_attr(%Xmlel{attrs: attrs}, name, default \\ nil) do
    Map.get(attrs, name, default)
  end

  @doc """
  Deletes an attribute from a Xmlel struct.

  Examples:
      iex> attrs = %{"id" => "100", "name" => "Alice"}
      iex> xmlel = %Exampple.Xml.Xmlel{attrs: attrs}
      iex> Exampple.Xml.Xmlel.get_attr(xmlel, "name")
      "Alice"
      iex> Exampple.Xml.Xmlel.delete_attr(xmlel, "name")
      iex> |> Exampple.Xml.Xmlel.get_attr("name")
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
      iex> %Exampple.Xml.Xmlel{attrs: attrs}
      iex> |> Exampple.Xml.Xmlel.put_attr("name", "Bob")
      iex> |> Exampple.Xml.Xmlel.get_attr("name")
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
      iex> Exampple.Xml.Xmlel.put_attrs(%Exampple.Xml.Xmlel{name: "foo"}, fields) |> to_string()
      "<foo city=\\"Cordoba\\" id=\\"100\\" name=\\"Alice\\"/>"

      iex> fields = %{"id" => "100", "name" => "Alice", "city" => :"Cordoba"}
      iex> Exampple.Xml.Xmlel.put_attrs(%Exampple.Xml.Xmlel{name: "foo"}, fields) |> to_string()
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
      iex> |> Exampple.Xml.Xmlel.parse()
      iex> |> Exampple.Xml.Xmlel.clean_spaces()
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

  @behaviour Access

  defp split_children(children, name) do
    children
    |> Enum.reduce(
      %{match: [], nonmatch: []},
      fn
        %Xmlel{name: ^name} = el, acc ->
          %{acc | match: [el | acc.match]}

        el, acc ->
          %{acc | nonmatch: [el | acc.nonmatch]}
      end
    )
    |> Enum.map(fn {k, v} -> {k, Enum.reverse(v)} end)
    |> Enum.into(%{})
  end

  @impl Access
  @doc """
  Access the value stored under key

  Examples:
      iex> import Exampple.Xml.Xmlel
      iex> el = ~x(<foo><c1 v="1"/><c1 v="2"/><c2/></foo>)
      iex> fetch(el, "c1")
      {:ok, [%Exampple.Xml.Xmlel{attrs: %{"v" => "1"}, children: [], name: "c1"}, %Exampple.Xml.Xmlel{attrs: %{"v" => "2"}, children: [], name: "c1"}]}
      iex> fetch(el, "nonexistent")
      :error
  """
  def fetch(%Xmlel{children: children}, key) do
    %{match: values} = split_children(children, key)

    if Enum.empty?(values) do
      :error
    else
      {:ok, values}
    end
  end

  @impl Access
  @doc """
  Access the value under key and update it at the same time

  Examples:
      iex> import Exampple.Xml.Xmlel
      iex> el = ~x(<foo><c1 v="1"/><c1 v="2"/><c2/></foo>)
      iex> fun = fn els ->
      iex> values = Enum.map(els, fn %Exampple.Xml.Xmlel{attrs: %{"v" => v}} = el -> %Exampple.Xml.Xmlel{el | attrs: %{"v" => "v" <> v}} end)
      iex> {els, values}
      iex> end
      iex> get_and_update(el, "c1", fun)
      {[%Exampple.Xml.Xmlel{attrs: %{"v" => "1"}, children: [], name: "c1"}, %Exampple.Xml.Xmlel{attrs: %{"v" => "2"}, children: [], name: "c1"}], %Exampple.Xml.Xmlel{attrs: %{}, children: [%Exampple.Xml.Xmlel{attrs: %{"v" => "v1"}, children: [], name: "c1"}, %Exampple.Xml.Xmlel{attrs: %{"v" => "v2"}, children: [], name: "c1"}, %Exampple.Xml.Xmlel{attrs: %{}, children: [], name: "c2"}], name: "foo"}}
      iex> fun = fn _els -> :pop end
      iex> get_and_update(el, "c1", fun)
      {[%Exampple.Xml.Xmlel{attrs: %{"v" => "1"}, children: [], name: "c1"}, %Exampple.Xml.Xmlel{attrs: %{"v" => "2"}, children: [], name: "c1"}], %Exampple.Xml.Xmlel{attrs: %{}, children: [%Exampple.Xml.Xmlel{attrs: %{}, children: [], name: "c2"}], name: "foo"}}
  """
  def get_and_update(%Xmlel{children: children} = el, key, function) do
    %{match: match, nonmatch: nonmatch} = split_children(children, key)

    case function.(if Enum.empty?(match), do: nil, else: match) do
      :pop ->
        {match, %Xmlel{el | children: nonmatch}}

      {get_value, update_value} ->
        {get_value, %Xmlel{el | children: update_value ++ nonmatch}}
    end
  end

  @impl Access
  @doc """
  Pop the value under key

  Examples:
      iex> import Exampple.Xml.Xmlel
      iex> el = ~x(<foo><c1 v="1"/><c1 v="2"/><c2/></foo>)
      iex> pop(el, "c1")
      {[%Exampple.Xml.Xmlel{attrs: %{"v" => "1"}, children: [], name: "c1"}, %Exampple.Xml.Xmlel{attrs: %{"v" => "2"}, children: [], name: "c1"}], %Exampple.Xml.Xmlel{attrs: %{}, children: [%Exampple.Xml.Xmlel{attrs: %{}, children: [], name: "c2"}], name: "foo"}}
      iex> pop(el, "nonexistent")
      {[], %Exampple.Xml.Xmlel{attrs: %{}, children: [%Exampple.Xml.Xmlel{attrs: %{"v" => "1"}, children: [], name: "c1"}, %Exampple.Xml.Xmlel{attrs: %{"v" => "2"}, children: [], name: "c1"}, %Exampple.Xml.Xmlel{attrs: %{}, children: [], name: "c2"}], name: "foo"}}
  """
  def pop(%Xmlel{children: children} = el, key) do
    case split_children(children, key) do
      %{match: []} ->
        {[], el}

      %{match: match, nonmatch: nonmatch} ->
        {match, %Xmlel{el | children: nonmatch}}
    end
  end
end

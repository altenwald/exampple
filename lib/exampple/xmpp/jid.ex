defmodule Exampple.Xmpp.Jid do
  @moduledoc """
  JID stands for Jabber Identification. This is de Identification the XMPP
  network provide for all of the users, servers and components which can be
  connected and reachable inside of the XMPP protocol.

  This module is a facility to handle JID data helping to parse it and
  convert it again to string. Provides the `~j` sigil which help us to
  define JIDs in the way `~j[user@domain/res]` and be converted into a
  JID structure.
  """
  alias Exampple.Xmpp.Jid

  defstruct node: "", server: "", resource: "", original: nil

  @typedoc """
  JID.`t` represents the structure in use to handle the identification
  for a user, component or server inside of a XMPP network. It is formed
  by the `node`, `server` and `resource`.
  """
  @type t :: %__MODULE__{node: String.t(), server: String.t(), resource: String.t()}

  @spec is_full?(binary | t()) :: boolean | {:error, :enojid}
  @doc """
  A boolean function to determine if the `jid` passed as parameter is
  a full JID or not. The parameter could be in binary format or as
  a JID structure.

  Remember that a full JID is a JID which has node, domain and
  resource. Actually is enough if the node is missing, but the
  resource should appears.

  Examples:
      iex> Exampple.Xmpp.Jid.is_full?("alice@example.com")
      false

      iex> Exampple.Xmpp.Jid.is_full?("comp.example.com/data")
      true

      iex> Exampple.Xmpp.Jid.is_full?("bob@example.com/res")
      true

      iex> Exampple.Xmpp.Jid.is_full?("/abc/xyz")
      {:error, :enojid}
  """
  def is_full?(jid) when is_binary(jid) do
    jid
    |> parse()
    |> is_full?()
  end

  def is_full?(%Jid{resource: ""}), do: false
  def is_full?(%Jid{}), do: true
  def is_full?(_), do: {:error, :enojid}

  @spec new(node :: binary, server :: binary, resource :: binary) :: t
  @doc """
  Creates a new JID passing `node`, `server` and `resource` data.

  Note that XMPP standard says the JID is case insensitive therefore,
  and to make easier the handle of comparisons, we put everything
  in downcase mode.

  Examples:
      iex> Exampple.Xmpp.Jid.new("foo", "bar", "baz")
      %Exampple.Xmpp.Jid{node: "foo", server: "bar", resource: "baz", original: "foo@bar/baz"}

      iex> Exampple.Xmpp.Jid.new("FOO", "BAR", "BAZ")
      %Exampple.Xmpp.Jid{node: "foo", server: "bar", resource: "BAZ", original: "FOO@BAR/BAZ"}
  """
  def new(node, server, resource) do
    original = to_string(%Jid{node: node || "", server: server, resource: resource || ""})
    node = String.downcase(node || "")
    server = String.downcase(server)
    resource = resource || ""
    %Jid{node: node, server: server, resource: resource, original: original}
  end

  @spec to_bare(binary | t()) :: binary
  @doc """
  Converts `jid` to a bare JID in binary format.

  Examples:
    iex> Exampple.Xmpp.Jid.to_bare("alice@example.com")
    "alice@example.com"

    iex> Exampple.Xmpp.Jid.to_bare("alice@example.com/resource")
    "alice@example.com"

    iex> Exampple.Xmpp.Jid.to_bare("example.com")
    "example.com"

    iex> Exampple.Xmpp.Jid.to_bare("example.com/resource")
    "example.com"
  """
  def to_bare(jid) when is_binary(jid) do
    jid
    |> parse()
    |> to_bare()
  end

  def to_bare(%Jid{node: "", server: server}), do: server
  def to_bare(%Jid{node: node, server: server}), do: "#{node}@#{server}"

  @spec parse(jid :: binary) :: t() | String.t() | {:error, :enojid}
  @doc """
  Parse a binary to a `jid` struct.

  Examples:
      iex> Exampple.Xmpp.Jid.parse("alice@example.com/resource")
      %Exampple.Xmpp.Jid{node: "alice", server: "example.com", resource: "resource", original: "alice@example.com/resource"}

      iex> Exampple.Xmpp.Jid.parse("AlicE@Example.Com/Resource")
      %Exampple.Xmpp.Jid{node: "alice", server: "example.com", resource: "Resource", original: "AlicE@Example.Com/Resource"}

      iex> Exampple.Xmpp.Jid.parse("alice@example.com")
      %Exampple.Xmpp.Jid{node: "alice", server: "example.com", original: "alice@example.com"}

      iex> Exampple.Xmpp.Jid.parse("AlicE@Example.Com")
      %Exampple.Xmpp.Jid{node: "alice", server: "example.com", original: "AlicE@Example.Com"}

      iex> Exampple.Xmpp.Jid.parse("example.com/resource")
      %Exampple.Xmpp.Jid{server: "example.com", resource: "resource", original: "example.com/resource"}

      iex> Exampple.Xmpp.Jid.parse("Example.Com/Resource")
      %Exampple.Xmpp.Jid{server: "example.com", resource: "Resource", original: "Example.Com/Resource"}

      iex> Exampple.Xmpp.Jid.parse("example.com")
      %Exampple.Xmpp.Jid{server: "example.com", original: "example.com"}

      iex> Exampple.Xmpp.Jid.parse("Example.Com")
      %Exampple.Xmpp.Jid{server: "example.com", original: "Example.Com"}

      iex> Exampple.Xmpp.Jid.parse(nil)
      nil

      iex> Exampple.Xmpp.Jid.parse("")
      ""

      iex> Exampple.Xmpp.Jid.parse("/example.com/resource")
      {:error, :enojid}
  """
  def parse(nil), do: nil
  def parse(""), do: ""

  def parse(jid) when is_binary(jid) do
    opts = [capture: :all_but_first]

    case Regex.run(~r/^(?:([^@]+)@)?([^@\/]+)(?:\/(.*))?$/, jid, opts) do
      [node, server] ->
        node = String.downcase(node)
        server = String.downcase(server)
        %Jid{node: node, server: server, original: jid}

      [node, server, res] ->
        node = String.downcase(node)
        server = String.downcase(server)
        %Jid{node: node, server: server, resource: res, original: jid}

      nil ->
        {:error, :enojid}
    end
  end

  @doc """
  This sigil help us to define JIDs using a simple format and get
  their struct representation from `binary`.

  Examples:
      iex> import Exampple.Xmpp.Jid
      iex> ~j[alice@example.com/ios]
      %Exampple.Xmpp.Jid{node: "alice", server: "example.com", resource: "ios", original: "alice@example.com/ios"}
  """
  def sigil_j(binary, _opts) do
    parse(binary)
  end

  defimpl String.Chars, for: __MODULE__ do
    @doc """
    Convert `jid` struct to string.

    Example:
      iex> to_string(%Exampple.Xmpp.Jid{server: "example.com"})
      "example.com"

      iex> to_string(%Exampple.Xmpp.Jid{server: "example.com", resource: "ios"})
      "example.com/ios"

      iex> to_string(%Exampple.Xmpp.Jid{node: "alice", server: "example.com"})
      "alice@example.com"

      iex> to_string(%Exampple.Xmpp.Jid{node: "alice", server: "example.com", resource: "ios"})
      "alice@example.com/ios"
    """
    def to_string(%Jid{original: original}) when is_binary(original), do: original
    def to_string(%Jid{node: "", server: server, resource: ""}), do: server
    def to_string(%Jid{node: "", server: server, resource: res}), do: "#{server}/#{res}"
    def to_string(%Jid{node: node, server: server, resource: ""}), do: "#{node}@#{server}"
    def to_string(%Jid{node: node, server: server, resource: res}), do: "#{node}@#{server}/#{res}"
  end
end

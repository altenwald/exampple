defmodule Exampple.Xmpp.Jid do

  alias Exampple.Xmpp.Jid

  defstruct [node: "", server: "", resource: ""]

  @type t :: %__MODULE__{node: binary, server: binary, resource: binary}

  @spec is_full?(binary) :: boolean
  @doc """
  Returns true if the JID is a full JID, false otherwise.

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

  @spec to_bare(binary) :: binary
  @doc """
  Converts JID to a bare JID in binary format.

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

  @spec parse(jid :: binary) :: {binary, binary, binary} | {:error, :enojid}
  @doc """
  Parse a binary to a Jid struct.

  Examples:
    iex> Exampple.Xmpp.Jid.parse("alice@example.com/resource")
    %Exampple.Xmpp.Jid{node: "alice", server: "example.com", resource: "resource"}

    iex> Exampple.Xmpp.Jid.parse("alice@example.com")
    %Exampple.Xmpp.Jid{node: "alice", server: "example.com"}

    iex> Exampple.Xmpp.Jid.parse("example.com/resource")
    %Exampple.Xmpp.Jid{server: "example.com", resource: "resource"}

    iex> Exampple.Xmpp.Jid.parse("example.com")
    %Exampple.Xmpp.Jid{server: "example.com"}

    iex> Exampple.Xmpp.Jid.parse(nil)
    nil

    iex> Exampple.Xmpp.Jid.parse("/example.com/resource")
    {:error, :enojid}
  """
  def parse(nil), do: nil
  def parse(jid) when is_binary(jid) do
    opts = [capture: :all_but_first]
    case Regex.run(~r/^(?:([^@]+)@)?([^\/]+)(?:\/(.*))?$/, jid, opts) do
      [node, server] ->
          %Jid{node: node, server: server}
      [node, server, res] ->
          %Jid{node: node, server: server, resource: res}
      nil ->
          {:error, :enojid}
    end
  end

  defimpl String.Chars, for: __MODULE__ do
    @doc """
    Convert Jid struct to string.

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
    def to_string(%Jid{node: "", server: server, resource: ""}), do: server
    def to_string(%Jid{node: "", server: server, resource: res}), do: "#{server}/#{res}"
    def to_string(%Jid{node: node, server: server, resource: ""}), do: "#{node}@#{server}"
    def to_string(%Jid{node: node, server: server, resource: res}), do: "#{node}@#{server}/#{res}"
  end
end

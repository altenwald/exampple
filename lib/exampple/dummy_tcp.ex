defmodule Exampple.DummyTcp do
  @moduledoc false
  use GenServer
  require Logger

  import Kernel, except: [send: 2]

  alias Exampple.Xml.Xmlel

  def start(_host, _port) do
    client_pid = self()
    args = [client_pid]

    case GenServer.start_link(__MODULE__, args, name: __MODULE__) do
      {:error, {:already_started, _pid}} ->
        stop(__MODULE__)
        start(nil, nil)

      {:ok, pid} ->
        {:ok, pid}
    end
  end

  def stop() do
    stop(__MODULE__)
  end

  def dump() do
    GenServer.cast(__MODULE__, :dump)
  end

  def stop(pid) do
    GenServer.stop(pid)
  end

  def send(packet, pid) when is_binary(packet) do
    GenServer.cast(pid, {:send, packet})
  end

  def subscribe() do
    GenServer.cast(__MODULE__, {:subscribe, self()})
  end

  def sent() do
    GenServer.call(__MODULE__, :sent)
  end

  def wait_for_sent_xml(timeout \\ 5_000) do
    receive do
      packet when is_binary(packet) -> Xmlel.parse(packet)
    after
      timeout -> nil
    end
  end

  def are_all_sent?(stanzas, tries \\ 3, timeout \\ 500)

  def are_all_sent?([], _tries, _timeout), do: true

  def are_all_sent?(stanzas, 0, _timeut), do: {false, stanzas}

  def are_all_sent?([stanza|stanzas], tries, timeout) do
    receive do
      ^stanza ->
        are_all_sent?(stanzas, tries, timeout)
    after timeout ->
      are_all_sent?(stanzas ++ [stanza], tries - 1, timeout)
    end
  end


  def received(%Xmlel{} = packet) do
    received(to_string(packet))
  end

  def received(packet) when is_binary(packet) do
    GenServer.cast(__MODULE__, {:received, packet})
  end

  @impl GenServer
  def init([client_pid]) do
    {:ok, %{client_pid: client_pid, subscribed: nil, stream: []}}
  end

  defp xml_init() do
    "<?xml version='1.0'?>" <>
      "<stream:stream id='16272490714779491840' xml:lang='en' " <>
      "xmlns:stream='http://etherx.jabber.org/streams' " <>
      "from='plan.example.com' xmlns='jabber:component:accept'>"
  end

  @impl GenServer
  def handle_cast({:send, "<?xml version='1.0' " <> _}, data) do
    Kernel.send(data.client_pid, {:tcp, self(), xml_init()})
    {:noreply, data}
  end

  def handle_cast({:send, "<handshake>" <> _}, data) do
    Kernel.send(data.client_pid, {:tcp, self(), "<handshake/>"})
    {:noreply, data}
  end

  def handle_cast({:send, packet}, data) do
    if pid = data.subscribed, do: Kernel.send(pid, packet)
    {:noreply, %{data | stream: data.stream ++ [packet]}}
  end

  def handle_cast({:received, packet}, data) do
    Kernel.send(data.client_pid, {:tcp, self(), packet})
    {:noreply, data}
  end

  def handle_cast({:subscribe, pid}, data) do
    {:noreply, Map.put(data, :subscribed, pid)}
  end

  def handle_cast(:dump, data) do
    {:noreply, %{data | stream: []}}
  end

  @impl GenServer
  def handle_call(:sent, _from, %{stream: []} = data), do: {:reply, nil, data}

  def handle_call(:sent, _from, %{stream: [packet | packets]} = data) do
    {:reply, packet, %{data | stream: packets}}
  end

  @impl GenServer
  def terminate(_reason, data) do
    Kernel.send(data.client_pid, {:tcp_closed, self()})
    :ok
  end
end

defmodule Exampple.DummyTcp do
  @moduledoc false
  use GenServer

  def start(_host, _port) do
    client_pid = self()

    case GenServer.start_link(__MODULE__, [client_pid], name: __MODULE__) do
      {:error, {:already_started, _pid}} ->
        stop(__MODULE__)
        start(nil, nil)

      {:ok, pid} ->
        {:ok, pid}

      _ = error ->
        error
    end
  end

  def stop(pid) do
    GenServer.stop(pid)
  end

  def send(packet, pid) do
    GenServer.cast(pid, {:send, packet})
  end

  def sent() do
    GenServer.call(__MODULE__, :sent)
  end

  def received(packet) do
    GenServer.cast(__MODULE__, {:received, packet})
  end

  @impl GenServer
  def init([client_pid]) do
    {:ok, %{client_pid: client_pid, stream: []}}
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
    {:noreply, %{data | stream: data.stream ++ [packet]}}
  end

  def handle_cast({:received, packet}, data) do
    Kernel.send(data.client_pid, {:tcp, self(), packet})
    {:noreply, data}
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

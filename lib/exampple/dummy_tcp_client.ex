defmodule Exampple.DummyTcpClient do
  @moduledoc false
  use GenServer
  require Logger

  import Kernel, except: [send: 2]

  alias Exampple.Xml.Xmlel

  @doc false
  def start(_host, _port) do
    client_pid = self()
    args = [client_pid]

    case GenServer.start_link(__MODULE__, args, name: __MODULE__) do
      {:error, {:already_started, _pid}} ->
        try do
          # a race condition could happens here so, we protect the
          # stop function calling from errors of the kind "noproc".
          stop(__MODULE__)
        catch
          :exit, {:noproc, _} -> :ok
        end

        start(nil, nil)

      {:ok, pid} ->
        {:ok, pid}
    end
  end

  @doc false
  def dump(pid \\ __MODULE__) do
    GenServer.cast(pid, :dump)
  end

  @doc false
  def stop(pid \\ __MODULE__) do
    GenServer.stop(pid)
  end

  @doc false
  def send(packet, pid \\ __MODULE__) when is_binary(packet) do
    GenServer.cast(pid, {:send, packet})
  end

  @doc false
  def subscribe(pid \\ nil) do
    pid = if pid, do: pid, else: self()
    GenServer.cast(__MODULE__, {:subscribe, pid})
  end

  @doc false
  def sent(pid \\ __MODULE__) do
    GenServer.call(pid, :sent)
  end

  @doc false
  def wait_for_sent_xml(timeout \\ 5_000) do
    receive do
      packet when is_binary(packet) ->
        {xmlel, _rest} = Xmlel.parse(packet)
        xmlel
    after
      timeout -> nil
    end
  end

  @doc false
  def are_all_sent?(stanzas, timeout \\ 500)

  def are_all_sent?([], _timeout), do: true

  def are_all_sent?(stanzas, timeout) do
    case wait_for_sent_xml(timeout) do
      %Xmlel{} = stanza ->
        if stanza in stanzas do
          Logger.debug("stanza found: #{to_string(stanza)}")
          are_all_sent?(stanzas -- [stanza], timeout)
        else
          throw({:unknown_stanza, to_string(stanza)})
        end

      nil ->
        throw({:missing_stanzas, for(i <- stanzas, do: to_string(i))})
    end
  end

  @doc false
  def received(%Xmlel{} = packet) do
    received(to_string(packet))
  end

  def received(packet) when is_binary(packet) do
    GenServer.cast(__MODULE__, {:received, packet})
  end

  @impl GenServer
  @doc false
  def init([client_pid]) do
    {:ok, %{client_pid: client_pid, subscribed: nil, stream: []}}
  end

  defp xml_init() do
    "<?xml version='1.0'?>" <>
      "<stream:stream id='16272490714779491840' xml:lang='en' " <>
      "xmlns:stream='http://etherx.jabber.org/streams' " <>
      "from='example.com' xmlns='jabber:client' " <>
      "version='1.0'>"
  end

  @impl GenServer
  @doc false
  def handle_cast({:send, "<?xml version='1.0'" <> _}, data) do
    Kernel.send(data.client_pid, {:tcp, self(), xml_init()})
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
  @doc false
  def handle_call(:sent, _from, %{stream: []} = data), do: {:reply, nil, data}

  def handle_call(:sent, _from, %{stream: [packet | packets]} = data) do
    {:reply, packet, %{data | stream: packets}}
  end

  @impl GenServer
  @doc false
  def terminate(_reason, data) do
    Kernel.send(data.client_pid, {:tcp_closed, self()})
    :ok
  end
end

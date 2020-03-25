defmodule Exampple.Component do
  use GenStateMachine, callback_mode: :handle_event_function
  require Logger

  alias Exampple.Xml.Xmlel
  alias Exampple.Xml.Stream, as: XmlStream
  alias Exampple.Router.Conn

  @default_tcp_handler Exampple.Tcp
  @default_router_handler Exampple.Router

  defmodule Data do
    defstruct socket: nil,
              stream: nil,
              host: nil,
              domain: nil,
              port: 5280,
              password: nil,
              trimmed: false,
              set_from: false,
              ping: false,
              tcp_handler: Tcp,
              router_handler: Router
  end

  defp xml_init(domain) do
    "<?xml version='1.0' encoding='UTF-8'?>" <>
      "<stream:stream to='#{domain}' " <>
      "xmlns='jabber:component:accept' " <>
      "xmlns:stream='http://etherx.jabber.org/streams'>"
  end

  defp xml_auth(password) do
    "<handshake>#{password}</handshake>"
  end

  defmacro __usign__(_) do
    quote do
      import Exampple.Component, only: [send: 1]

      import Exampple.Xmpp.Stanza,
        only: [
          message_resp: 2,
          message_error: 2,
          iq_resp: 1,
          iq_resp: 2,
          iq_error: 2
        ]
    end
  end

  def start_link(name, args) do
    GenStateMachine.start_link(__MODULE__, args, name: name)
  end

  def start_link(args), do: start_link(__MODULE__, args)

  @spec connect() :: :ok
  def connect() do
    :ok = GenStateMachine.cast(__MODULE__, :connect)
  end

  @spec disconnect() :: :ok
  def disconnect() do
    :ok = GenStateMachine.stop(__MODULE__)
  end

  @spec send(binary | Router.Conn.t()) :: :ok
  def send(data) when is_binary(data) do
    GenStateMachine.cast(__MODULE__, {:send, data})
  end

  def send(%Conn{response: response} = conn) when response != nil do
    data = to_string(conn.response)
    GenStateMachine.cast(__MODULE__, {:send, data})
  end

  @impl GenStateMachine
  def init(%{host: host, port: port, domain: domain, password: password} = cfg) do
    trimmed = Map.get(cfg, :trimmed, false)
    set_from = Map.get(cfg, :set_from, false)
    ping = Map.get(cfg, :ping, false)
    router_handler = Map.get(cfg, :router_handler, @default_router_handler)
    tcp_handler = Map.get(cfg, :tcp_handler, @default_tcp_handler)

    events =
      if Map.get(cfg, :auto_connect, false) do
        [{:next_event, :cast, :connect}]
      else
        []
      end

    {:ok, :disconnected,
     %Data{
       host: host,
       port: port,
       domain: domain,
       password: password,
       trimmed: trimmed,
       set_from: set_from,
       ping: ping,
       router_handler: router_handler,
       tcp_handler: tcp_handler
     }, events}
  end

  def disconnected(type, :connect, %Data{host: host, port: port} = data)
      when type in [:cast, :state_timeout] do
    case data.tcp_handler.start(host, port) do
      {:ok, socket} ->
        {:next_state, :connected, %Data{data | socket: socket},
         [{:next_event, :cast, :stream_init}]}

      error ->
        Logger.error("connecting error [#{host}:#{port}]: #{inspect(error)}")
        {:next_state, :retrying, data, [{:next_event, :cast, :connect}]}
    end
  end

  def retrying(:cast, :connect, data) do
    {:next_state, :disconnected, data, [{:state_timeout, 3_000, :connect}]}
  end

  def connected(:cast, :stream_init, %Data{} = data) do
    stream = XmlStream.new()
    {:next_state, :stream_init, %Data{data | stream: stream}, [{:next_event, :cast, :init}]}
  end

  def stream_init(:cast, :init, data) do
    data.domain
    |> xml_init()
    |> data.tcp_handler.send(data.socket)

    :keep_state_and_data
  end

  def stream_init(:info, {:xmlstreamstart, name, attrs}, data) do
    xmlel = Xmlel.new(name, attrs)

    case Xmlel.get_attr(xmlel, "id") do
      stream_id when is_binary(stream_id) ->
        data = %Data{data | stream: XmlStream.new()}
        {:next_state, :authenticate, data, [{:next_event, :internal, {:handshake, stream_id}}]}

      false ->
        Logger.error("stream invalid, no Stream ID")
        :gen_tcp.close(data.socket)
        {:next_state, :retrying, data, [{:next_event, :cast, :connect}]}
    end
  end

  def authenticate(:internal, {:handshake, stream_id}, data) do
    stream_id
    |> get_handshake(data.password)
    |> Integer.to_string(16)
    |> String.downcase()
    |> xml_auth()
    |> data.tcp_handler.send(data.socket)

    :keep_state_and_data
  end

  def authenticate(:info, {:xmlelement, %Xmlel{name: "handshake", children: []}}, data) do
    {:next_state, :ready, %Data{data | stream: XmlStream.new()}, timeout_action(data)}
  end

  def authenticate(:info, {:xmlelement, %Xmlel{name: "stream:error"} = xmlel}, data) do
    raise ArgumentError, """

    ******************************************
    The system is NOT configured properly, it was returning:
    #{to_string(xmlel)}
    ******************************************
    """

    {:stop, :normal, data}
  end

  defp get_handshake(stream_id, secret) do
    <<mac::integer-size(160)>> = :crypto.hash(:sha, "#{stream_id}#{secret}")
    mac
  end

  def ready({:timeout, :ping}, :send_ping, data) do
    data.tcp_handler.send("\n", data.socket)
    {:keep_state_and_data, timeout_action(data)}
  end

  def ready(:info, {:send, packet}, %Data{set_from: true} = data) do
    packet
    |> Xmlel.parse()
    |> Xmlel.put_attr("from", data.domain)
    |> to_string()
    |> data.tcp_handler.send(data.socket)

    {:keep_state_and_data, timeout_action(data)}
  end

  def ready(:cast, {:send, packet}, data) do
    Logger.debug("send packet: #{inspect(packet)}")
    data.tcp_handler.send(packet, data.socket)
    {:keep_state_and_data, timeout_action(data)}
  end

  def ready(:info, {:xmlelement, packet}, %Data{trimmed: true} = data) do
    Logger.debug("received packet: #{inspect(packet)}")

    packet
    |> Xmlel.clean_spaces()
    |> data.router_handler.route(data.domain)

    stream = XmlStream.new()
    {:keep_state, %Data{data | stream: stream}, timeout_action(data)}
  end

  def ready(:info, {:xmlelement, packet}, %Data{trimmed: false} = data) do
    Logger.debug("received packet: #{inspect(packet)}")
    data.router_handler.route(packet)
    stream = XmlStream.new()
    {:keep_state, %Data{data | stream: stream}, timeout_action(data)}
  end

  @impl GenStateMachine
  def handle_event(:info, {:tcp, _socket, packet}, _state, data) do
    stream = XmlStream.parse(data.stream, packet)
    {:keep_state, %Data{data | stream: stream}}
  end

  def handle_event(:info, {:tcp_closed, _socket}, _state, data) do
    {:next_state, :retrying, data, [{:next_event, :cast, :connect}]}
  end

  def handle_event(:info, {:tcp_error, _socket, reason}, _state, data) do
    Logger.error("tcp closed error: #{inspect(reason)}")
    {:next_state, :retrying, data, [{:next_event, :cast, :connect}]}
  end

  def handle_event(:info, {:xmlstreamstart, _name, _attrs}, state, _data)
      when state != :stream_init do
    :keep_state_and_data
  end

  def handle_event(type, content, state, data) do
    apply(__MODULE__, state, [type, content, data])
  end

  defp timeout_action(%Data{ping: false}), do: []
  defp timeout_action(%Data{ping: ping}), do: [{{:timeout, :ping}, ping, :send_ping}]
end

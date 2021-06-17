defmodule Exampple.Component do
  @moduledoc """
  Component is letting us to connect to a XMPP server as a XMPP Component.
  This module aims create a connection as a process letting us handle
  the connection easily. By default, using the configuration it's starting
  using the module name as registerd name for the process.

  This module is designed to be in use in combination with `Exampple.Router`
  and the custom implementation of _controllers_ which are using this
  module and implementing the functions which were defined in the
  implementation of the router.

  Check the general documentation about the architecture and how to use it
  for further information.
  """
  use GenStateMachine, callback_mode: :handle_event_function
  require Logger

  alias Exampple.Xml.Xmlel
  alias Exampple.Xml.Stream, as: XmlStream
  alias Exampple.Router.Conn

  @default_tcp_handler Exampple.Tcp
  @default_router_handler Exampple.Router
  @default_stanza_timeout 5_000

  defmodule Data do
    @moduledoc false

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
              router_handler: Router,
              otp_app: nil,
              subscribed: nil,
              stanza_timeout: nil
  end

  defguard not_ready(state) when state != :ready

  defp xml_init(domain) do
    "<?xml version='1.0' encoding='UTF-8'?>" <>
      "<stream:stream to='#{domain}' " <>
      "xmlns='jabber:component:accept' " <>
      "xmlns:stream='http://etherx.jabber.org/streams'>"
  end

  defp xml_auth(password) do
    "<handshake>#{password}</handshake>"
  end

  @doc false
  defmacro __using__(_) do
    quote do
      import Exampple.Component, only: [send: 1]

      import Exampple.Xmpp.Stanza,
        only: [
          iq_error: 2,
          iq_resp: 1,
          iq_resp: 2,
          message_resp: 2,
          message_error: 2,
          error: 2
        ]
    end
  end

  @doc """
  Starts a process providing it a `name`. This function let you to
  create as many connections as component as needed. Check
  `start_link/1` for further information about `args`.
  """
  def start_link(name, args) do
    GenStateMachine.start_link(__MODULE__, args, name: name)
  end

  @doc """
  Starts a process using the module name (Exampple.Component) as the
  registered name. The arguments we can provide are the following:

  - `otp_app`: the name of the application. If you specify this only
    one parameter the rest of the configuration will be retrieved
    from the application configuration. This should be a keyword list.

  If we provide a map instead we can specify the following `args`:

  - `otp_app`: in this level it's only needed to be sent to the router.
  - `host`: the name of the host where the XMPP server is.
  - `port`: the port where the XMPP server is listening for the components.
  - `domain`: the XMPP domain. Note that it is not necessary the same as the host.
  - `trimmed`: if the XML packet will be trimmed (removing all of the empty nodes).
    default to `false`.
  - `set_from`: if we have to set the from for each stanza. Default `false`.
  - `ping`: if we want to send a ping to the server we can specify the time in
    milliseconds to send an `\n` and ensure the connection is not closed because
    of idle. Default is `false`.
  - `router_handler`: the module which is going to handle the routing. This is only
    for testing purposes. Default to `Exampple.Router`.
  - `tcp_handler`: the module which is going to handle the connection for the
    component. This could be useful for TLS handling or testing purposes. You can
    see further information in `Exampple.Tcp` and `Exampple.DummyTcpComponent`.
    Default to `Exampple.Tcp`.
  - `stanza_timeout`: the amount of time we wait until we kill the process and
    reply back an error. The error will be a `remote-server-timeout`.
  """
  def start_link(otp_app: otp_app) when is_atom(otp_app) do
    args =
      otp_app
      |> Application.get_env(__MODULE__)
      |> Enum.into(%{})
      |> Map.put(:otp_app, otp_app)

    start_link(args)
  end

  def start_link(args), do: start_link(__MODULE__, args)

  @spec connect() :: :ok
  @doc """
  Send the message to the component to perform the connection. This has effect
  only if the status of the server is `disconnected`.
  """
  def connect() do
    :ok = GenStateMachine.cast(__MODULE__, :connect)
  end

  @spec disconnect() :: :ok
  @doc """
  Send the message to the component to perform the disconnection. This has effect
  only if the status is different from `disconnected`.
  """
  def disconnect() do
    :ok = GenStateMachine.cast(__MODULE__, :disconnect)
  end

  @spec stop() :: :ok
  @doc """
  Stop the process and therefore performs the disconnection from the XMPP server
  if any.
  """
  def stop() do
    :ok = GenStateMachine.stop(__MODULE__)
  end

  @spec send(binary | Xmlel.t() | Conn.t()) :: :ok
  @doc """
  Send `data` using the socket to the XMPP server. You can send whatever binary data
  or a `%Xmlel{}` struct which will be converted first to string to be sent. It
  also works with `%Conn{}` but only if you stored the response inside of it. See
  `Exampple.Stanza` for further information.
  """
  def send(data) when is_binary(data) do
    GenStateMachine.cast(__MODULE__, {:send, data})
  end

  def send(%Xmlel{} = xmlel) do
    send(to_string(xmlel))
  end

  def send(%Conn{} = conn) do
    send(Conn.get_response(conn))
  end

  @spec subscribe() :: :ok
  @doc """
  Performs a subscription to the XMPP component. This means the component
  is going to notify when it's ready. This could be used for testing and
  for synchronization at start. Only one process could be subscribed at
  the same time.
  """
  def subscribe() do
    GenStateMachine.cast(__MODULE__, {:subscribe, self()})
  end

  @spec wait_for_ready() :: :ok
  @doc """
  Wait until the system is ready to start processing messages. This is in
  use for functional tests and could be used as a phase in the start of
  the applications.
  """
  def wait_for_ready() do
    subscribe()

    receive do
      :ready -> :ok
    after
      100 -> wait_for_ready()
    end
  end

  @impl GenStateMachine
  @doc false
  def init(%{host: host, port: port, domain: domain, password: password} = cfg) do
    trimmed = Map.get(cfg, :trimmed, false)
    set_from = Map.get(cfg, :set_from, false)
    ping = Map.get(cfg, :ping, false)
    router_handler = Map.get(cfg, :router_handler, @default_router_handler)
    tcp_handler = Map.get(cfg, :tcp_handler, @default_tcp_handler)
    otp_app = Map.get(cfg, :otp_app)
    stanza_timeout = Map.get(cfg, :stanza_timeout, @default_stanza_timeout)

    unless otp_app do
      raise """

      *****************
      You have to provide :otp_app to the Exampple.Component
      configuration!!!
      *****************
      """
    end

    events =
      case Map.get(cfg, :auto_connect, false) do
        true -> [{:next_event, :cast, :connect}]
        false -> []
        time when is_integer(time) -> [{:state_timeout, time, :connect}]
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
       tcp_handler: tcp_handler,
       otp_app: otp_app,
       stanza_timeout: stanza_timeout
     }, events}
  end

  @doc false
  def disconnected(type, :connect, %Data{host: host, port: port} = data)
      when type in [:cast, :state_timeout, :timeout] do
    case data.tcp_handler.start(host, port) do
      {:ok, socket} ->
        {:next_state, :connected, %Data{data | socket: socket},
         [{:next_event, :cast, :stream_init}]}

      error ->
        Logger.error("connecting error [#{host}:#{port}]: #{inspect(error)}")
        {:next_state, :retrying, data, [{:next_event, :cast, :connect}]}
    end
  end

  def disconnected(:info, {:xmlelement, _xmlel}, _data) do
    {:keep_state_and_data, [postpone: true]}
  end

  @doc false
  def retrying(:cast, :connect, data) do
    {:next_state, :disconnected, data, [{:state_timeout, 3_000, :connect}]}
  end

  def retrying(:info, {:xmlelement, _xmlel}, _data) do
    {:keep_state_and_data, [postpone: true]}
  end

  @doc false
  def connected(:cast, :stream_init, %Data{} = data) do
    stream = XmlStream.new()
    {:next_state, :stream_init, %Data{data | stream: stream}, [{:next_event, :cast, :init}]}
  end

  @doc false
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
        data.tcp_handler.stop(data.socket)
        {:next_state, :retrying, data, [{:next_event, :cast, :connect}]}
    end
  end

  def stream_init(:info, {:xmlelement, _xmlel}, _data) do
    {:keep_state_and_data, [postpone: true]}
  end

  @doc false
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
    if pid = data.subscribed, do: send(pid, :ready)
    {:next_state, :ready, %Data{data | stream: XmlStream.new()}, timeout_action(data)}
  end

  def authenticate(:info, {:xmlelement, %Xmlel{name: "stream:error"} = xmlel}, data) do
    Logger.error("cannot authenticate: #{to_string(xmlel)}")

    raise ArgumentError, """

    ******************************************
    The system is NOT configured properly, it was returning:
    #{to_string(xmlel)}
    ******************************************
    """

    {:stop, :normal, data}
  end

  def authenticate(:info, {:xmlelement, _xmlel}, _data) do
    {:keep_state_and_data, [postpone: true]}
  end

  defp get_handshake(stream_id, secret) do
    <<mac::integer-size(160)>> = :crypto.hash(:sha, "#{stream_id}#{secret}")
    mac
  end

  @doc false
  def ready({:timeout, :ping}, :send_ping, data) do
    data.tcp_handler.send("\n", data.socket)
    {:keep_state_and_data, timeout_action(data)}
  end

  def ready(:cast, {:send, packet}, %Data{set_from: true} = data) do
    packet
    |> Xmlel.parse()
    |> elem(0)
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
    %Data{domain: domain, otp_app: otp_app, stanza_timeout: timeout} = data

    packet
    |> Xmlel.clean_spaces()
    |> data.router_handler.route(domain, otp_app, timeout)

    {:keep_state_and_data, timeout_action(data)}
  end

  def ready(:info, {:xmlelement, packet}, %Data{trimmed: false} = data) do
    Logger.debug("received packet: #{inspect(packet)}")
    %Data{domain: domain, otp_app: otp_app, stanza_timeout: timeout} = data
    data.router_handler.route(packet, domain, otp_app, timeout)
    {:keep_state_and_data, timeout_action(data)}
  end

  @impl GenStateMachine
  @doc false
  def handle_event(:cast, :disconnect, :disconnected, _data) do
    :keep_state_and_data
  end

  def handle_event(:cast, :disconnect, _state, data) do
    data.tcp_handler.stop(data.socket)
    {:next_state, :disconnected, data}
  end

  def handle_event(:info, {:tcp, socket, packet}, _state, data) do
    case XmlStream.parse(data.stream, packet) do
      {:cont, partial} ->
        {:keep_state, %Data{data | stream: partial}}

      {:halt, _user, "</stream:stream>"} ->
        stream = XmlStream.new()
        {:keep_state, %Data{data | stream: stream}}

      {:halt, _user, rest} ->
        stream = XmlStream.new()
        actions = [{:next_event, :info, {:tcp, socket, rest}}]
        {:keep_state, %Data{data | stream: stream}, actions}

      {:error, error} ->
        Logger.error("failing packet: #{inspect(packet)}")
        Logger.error("parsing error: #{inspect(error)}")
        data.tcp_handler.stop(data.socket)
        {:next_state, :retrying, data, [{:next_event, :cast, :connect}]}
    end
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

  def handle_event(:info, :xmlstartdoc, _state, _data) do
    :keep_state_and_data
  end

  def handle_event(:info, {:xmlstreamend, _name}, _state, _data) do
    :keep_state_and_data
  end

  def handle_event(:info, :xmlenddoc, _state, _data) do
    :keep_state_and_data
  end

  def handle_event(:cast, {:subscribe, pid}, :ready, data) do
    send(pid, :ready)
    {:keep_state, %Data{data | subscribed: pid}}
  end

  def handle_event(:cast, {:subscribe, pid}, _state, data) do
    {:keep_state, %Data{data | subscribed: pid}}
  end

  def handle_event(:cast, {:send, _packet}, state, _data) when not_ready(state) do
    {:keep_state_and_data, [:postpone]}
  end

  def handle_event(type, content, state, data) do
    apply(__MODULE__, state, [type, content, data])
  end

  defp timeout_action(%Data{ping: false}), do: []
  defp timeout_action(%Data{ping: ping}), do: [{{:timeout, :ping}, ping, :send_ping}]
end

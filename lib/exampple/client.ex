defmodule Exampple.Client do
  @moduledoc """
  Client is a simple state machine inside of a process which helps
  us to create a client connection to a XMPP Server. The dynamic
  of the connection is contained inside of the client when we
  perform the connection and then we can send different kind of
  stanzas to the server.

  The aim of this Client is to create a simple way to test the system
  but you can use it even to create bots based on XMPP.

  It has the possibility to register templates and returns back the
  stanzas which are being received from the XMPP server to the calling
  process. This way we are responsible of the communication.
  """
  use GenStateMachine, callback_mode: :handle_event_function
  require Logger

  import Kernel, except: [send: 2]

  alias Exampple.Router.Conn
  alias Exampple.Tls
  alias Exampple.Xml.Stream, as: XmlStream

  @default_tcp_handler Exampple.Tcp
  @default_tls_handler Exampple.Tls

  @type hook_name() :: String.t()
  @type hook_function() :: (Conn.t() -> {:ok, Conn.t()} | :drop)

  defmodule Data do
    alias Exampple.Client

    @moduledoc false
    @type t() :: %__MODULE__{
            socket: nil | :gen_tcp.socket(),
            tls_socket: nil | :ssl.sslsocket(),
            stream: nil | Saxy.Partial.t(),
            host: nil | String.t(),
            domain: nil | String.t(),
            port: non_neg_integer(),
            trimmed: boolean(),
            set_from: boolean(),
            ping: boolean() | non_neg_integer(),
            tcp_handler: module(),
            tls_handler: module(),
            tracer_pids: %{ reference() => pid() },
            hooks: %{ Client.hook_name() => Client.hook_function() },
            name: nil | atom()
          }

    defstruct socket: nil,
              tls_socket: nil,
              stream: nil,
              host: nil,
              domain: nil,
              port: 5280,
              trimmed: false,
              set_from: false,
              ping: false,
              tcp_handler: Tcp,
              tls_handler: Tls,
              tracer_pids: %{},
              hooks: %{},
              name: nil
  end

  defp xml_init(domain) do
    "<?xml version='1.0' encoding='UTF-8'?>" <>
      "<stream:stream to='#{domain}' " <>
      "xmlns='jabber:client' " <>
      "xmlns:stream='http://etherx.jabber.org/streams' " <>
      "version='1.0'>"
  end

  defp xml_terminate(), do: "</stream:stream>"

  @doc """
  Starts the client. We can send a `name` to be registered or use
  the module name (`__MODULE__`) by default. As `args` the
  system requires a Map with the information for the connection.
  The information we can provide is:

  - `host`: the hostname or IP where we will be connected.
  - `port`: the port number where we will be connected.
  - `domain`: the XMPP domain we are going to use.
  - `trimmed`: if the stanzas will be trimmed (default `false`).
  - `set_from`: if we are going to set the `from` for each stanza
    written by the client (default `false`).
  - `ping`: if we active the ping. We can set here the number of
    milliseconds to send the ping or false to disable it (default
    `false`).
  - `tcp_handler`: the module which we will use to handle the
    connection (default `Exampple.Tcp`).
  - `tls_handler`: the module which we will use to handle the
    TLS connection, if any (default `Exampple.Tls`).
  - `trace`: indicate if you want to receive trace output from
    the client.
  """
  @spec start_link(atom() | pid(), map()) :: GenStateMachine.on_start()
  def start_link(name \\ __MODULE__, args) do
    GenStateMachine.start_link(__MODULE__, [name, self(), args], name: name)
  end

  @doc """
  Send a message to the client process to start the connection. Optionally,
  we can specify the `name` of the process where to connect, by default this
  is the value provided by `__MODULE__`.
  """
  @spec connect() :: :ok
  @spec connect(atom() | pid()) :: :ok
  def connect(name \\ __MODULE__) do
    :ok = GenStateMachine.cast(name, :connect)
  end

  @doc """
  Wait until the system is connected to start processing messages. This is in
  use for functional tests and could be used as a phase in the start of
  the applications.
  """
  @spec wait_for_connected() :: :ok | :timeout
  @spec wait_for_connected(atom() | pid()) :: :ok | :timeout
  def wait_for_connected(name \\ __MODULE__, sleep \\ 250, retries \\ 2)

  def wait_for_connected(_name, _sleep, 0) do
    :timeout
  end

  def wait_for_connected(name, sleep, retries) do
    if is_connected?(name) do
      :ok
    else
      Process.sleep(250)
      wait_for_connected(name, sleep, retries - 1)
    end
  end

  @doc """
  Upgrade a connection as TLS.
  """
  @spec upgrade_tls() :: :ok
  @spec upgrade_tls(atom() | pid()) :: :ok
  def upgrade_tls(name \\ __MODULE__) do
    :ok = GenStateMachine.cast(name, :upgrade_tls)
  end

  @doc """
  Send a message to the client process identified by `name` as PID
  or registered process to stop the connection. The `name` parameter
  is optional, by default it's set to `__MODULE__`.
  """
  @spec disconnect() :: :ok
  @spec disconnect(atom() | pid()) :: :ok
  def disconnect(name \\ __MODULE__) do
    :ok = GenStateMachine.cast(name, :disconnect)
  end

  @doc """
  Ask to the process about whether the connection is active. The checks are based
  on the process relanted to the passed `name` (it must be a registered name), the
  PID should be valid and alive, and then we ask to the client if it's connected.
  If no parameter is provided it is `__MODULE__`.
  """
  @spec is_connected?() :: boolean()
  @spec is_connected?(atom() | pid()) :: boolean()
  def is_connected?(name \\ __MODULE__) do
    with pid when is_pid(pid) <- Process.whereis(name),
         true <- Process.alive?(pid) do
      GenStateMachine.call(name, :is_connected?)
    else
      _ -> false
    end
  end

  @doc """
  Stops the process. You can specify the `name` of the process to be
  stopped, by default this value is set as `__MODULE__`.
  """
  @spec stop() :: :ok
  @spec stop(atom() | pid()) :: :ok
  def stop(name \\ __MODULE__) do
    :ok = GenStateMachine.stop(name)
  end

  @doc """
  Send information (stanzas) via the client process directly to the
  XMPP Server. These stanzas could be sent to whoever inside of the
  XMPP network locally or even to other domains if the network is
  federated.

  The accepted paramter `data_or_conn` could be a string (or binary)
  or a `Conn` struct. Optionally, you can specify a second parameter
  as the `name` of the registered process. The default value for the
  `name` paramter is `__MODULE__`.

  Example:
      iex> Exampple.Client.send("<presence/>")
      :ok
  """
  @spec send(binary | Conn.t()) :: :ok
  @spec send(binary | Conn.t(), GenServer.server()) :: :ok

  def send(data_or_conn, name \\ __MODULE__)

  def send(data, name) when is_binary(data) do
    GenStateMachine.cast(name, {:send, data})
  end

  def send(%Conn{response: response} = conn, name) when response != nil do
    data = to_string(conn.response)
    GenStateMachine.cast(name, {:send, data})
  end

  @doc """
  Add process as a tracer for the current XMPP client. It let us receive
  all of the events happening inside of the client. We can have as many
  tracers as needed.
  """
  @spec trace(boolean()) :: :ok
  @spec trace(GenServer.server(), enable? :: boolean()) :: :ok
  def trace(name \\ __MODULE__, enable?) when is_boolean(enable?) do
    GenStateMachine.cast(name, {:trace, enable?, self()})
  end

  @doc """
  Add hook letting us to run a specific code for a received stanza. The
  hooks should be anonymous functions in the way:

  ```
  fn conn ->
    if conn.stanza_type == "iq" and conn.type == "result" do
      :drop
    else
      {:ok, conn}
    end
  end
  ```

  These functions let us stop processing of the stanzas or add specific
  listeners for an incoming stanza we are awaiting for. For example, if
  we want to get the stanza in our process:

  ```
  parent = self()
  f = fn conn ->
    if conn.stanza_type == "iq" and conn.type == "error" do
      send(parent, {:stanza_error, conn.stanza})
    end
    {:ok, conn}
  end
  """
  @spec add_hook(hook_name, hook_function) :: :ok
  @spec add_hook(GenServer.server(), hook_name, hook_function) :: :ok
  def add_hook(name \\ __MODULE__, hook_name, hook_function) do
    :ok = GenStateMachine.cast(name, {:add_hook, hook_name, hook_function})
  end

  @spec del_hook(hook_name) :: :ok
  @spec del_hook(GenServer.server(), hook_name) :: :ok
  def del_hook(name \\ __MODULE__, hook_name) do
    :ok = GenStateMachine.cast(name, {:del_hook, hook_name})
  end

  @impl GenStateMachine
  @doc false
  def init([name, pid, %{host: host, port: port, domain: domain} = cfg]) do
    state_data = %Data{
      name: name,
      stream: nil,
      host: host,
      domain: domain,
      port: port,
      trimmed: Map.get(cfg, :trimmed, false),
      set_from: Map.get(cfg, :set_from, false),
      ping: Map.get(cfg, :ping, false),
      tcp_handler: Map.get(cfg, :tcp_handler, @default_tcp_handler),
      tls_handler: Map.get(cfg, :tls_handler, @default_tls_handler),
      tracer_pids: if(Map.get(cfg, :trace, false), do: to_subscribe(%{}, pid), else: %{})
    }

    {:ok, :disconnected, state_data}
  end

  defp to_subscribe(tracer_pids, pid) do
    ref = Process.monitor(pid)
    Map.put(tracer_pids, ref, pid)
  end

  defp trace(%Data{tracer_pids: pids, name: name}, event_name, event_data) do
    Enum.each(pids, fn {_, pid} ->
      Kernel.send(pid, {event_name, self(), Keyword.put(event_data, :name, name)})
    end)
  end

  defp apply_hooks(conn, %Data{hooks: []}), do: conn
  defp apply_hooks(conn, %Data{hooks: hooks}) do
    Enum.reduce(hooks, conn, fn {hook_name, hook_function}, conn_acc ->
      try do
        Logger.debug("running hook #{hook_name} on #{to_string(conn.stanza)}")
        hook_function.(conn_acc)
      rescue
        error ->
          Logger.error("failed hook #{hook_name} on #{to_string(conn.stanza)} with #{inspect(error)}")
          conn_acc
      end
    end)
  end

  @doc false
  def disconnected(:cast, :connect, data) do
    case data.tcp_handler.start(data.host, data.port) do
      {:ok, socket} ->
        stream = XmlStream.new()
        xml_init = xml_init(data.domain)
        data.tcp_handler.send(xml_init, socket)
        trace(data, :sent, packet: xml_init)
        data = %Data{data | socket: socket, stream: stream}
        trace(data, :connected, [])
        {:next_state, :connected, data, timeout_action(data)}

      error ->
        Logger.error("connect error #{data.host}:#{data.port}: #{inspect(error)}")
        trace(data, :connection_error, [error_message: error])
        :keep_state_and_data
    end
  end

  def disconnected(:cast, {:send, packet}, data) do
    Logger.error("cannot process sent, we're still disconnected!")
    trace(data, :send_error, [
      error_message: "cannot process sent, still disconnected",
      error_data: packet
    ])
    :keep_state_and_data
  end

  def disconnected(:cast, :upgrade_tls, data) do
    Logger.error("cannot process upgrade TLS, we're still disconnected!")
    trace(data, :upgrade_tls_error, [
      error_message: "cannot process upgrade TLS, still disconnected"
    ])
    :keep_state_and_data
  end

  def disconnected({:timeout, :ping}, :send_ping, _data) do
    :keep_state_and_data
  end

  @doc false
  def connected(:info, {:xmlelement, xmlel}, data) do
    conn =
      xmlel
      |> Conn.new()
      |> apply_hooks(data)

    trace(data, :received, conn: conn)
    :keep_state_and_data
  end

  def connected(:info, {:xmlstreamstart, _name, _attrs}, data) do
    {:keep_state_and_data, timeout_action(data)}
  end

  def connected(:info, {:xmlstreamend, _name}, data) do
    {:keep_state_and_data, timeout_action(data)}
  end

  def connected(:info, :xmlstartdoc, data) do
    {:keep_state_and_data, timeout_action(data)}
  end

  def connected(:cast, {:send, packet}, data) when is_binary(packet) do
    data.tcp_handler.send(packet, get_socket(data))
    trace(data, :sent, packet: packet)
    :keep_state_and_data
  end

  def connected(:cast, :upgrade_tls, %Data{socket: socket, tls_socket: nil} = data) do
    case data.tls_handler.start(socket) do
      {:ok, tls_socket} ->
        stream = XmlStream.new()
        xml_init = xml_init(data.domain)
        data.tls_handler.send(xml_init, tls_socket)
        trace(data, :upgraded_tls)
        trace(data, :sent, packet: xml_init)

        {:keep_state,
         %Data{data | stream: stream, tls_socket: tls_socket, tcp_handler: data.tls_handler}}

      {:error, reason} ->
        Logger.error("start TLS failed due to: #{inspect(reason)}")
        trace(data, :error_upgrading_tls, [error_message: reason])
        :keep_state_and_data
    end
  end

  def connected(:cast, :upgrade_tls, _data) do
    Logger.warn("TLS was already connected!")
    :keep_state_and_data
  end

  def connected({:timeout, :ping}, :send_ping, data) do
    data.tcp_handler.send("\n", get_socket(data))
    trace(data, :sent, packet: :ping)
    {:keep_state_and_data, timeout_action(data)}
  end

  @impl GenStateMachine
  @doc false
  def terminate(_reason, :disconnected, _data), do: :ok

  def terminate(_reason, _state, data) do
    xml_terminate = xml_terminate()
    data.tcp_handler.send(xml_terminate, get_socket(data))
    trace(data, :sent, packet: xml_terminate)
    data.tcp_handler.stop(get_socket(data))
    trace(data, :terminated, [])
    :ok
  end

  @impl GenStateMachine
  @doc false
  def handle_event(:info, {type, socket, packet}, _state, data) when type in [:tcp, :ssl] do
    case XmlStream.parse(data.stream, packet) do
      {:cont, partial} ->
        {:keep_state, %Data{data | stream: partial}}

      {:halt, _user, "</stream:stream>"} ->
        stream = XmlStream.new()
        {:keep_state, %Data{data | stream: stream}}

      {:halt, _user, rest} ->
        stream = XmlStream.new()
        actions = [{:next_event, :info, {type, socket, rest}}]
        {:keep_state, %Data{data | stream: stream}, actions}

      {:error, error} ->
        Logger.error("failing packet: #{inspect(packet)}")
        Logger.error("parsing error: #{inspect(error)}")
        trace(data, :receive_error, packet: packet, error_message: error)
        data.tcp_handler.stop(data.socket)
        {:next_state, :retrying, data, [{:next_event, :cast, :connect}]}
    end
  end

  def handle_event(:info, {closed, _socket}, _state, data)
      when closed in [:tcp_closed, :ssl_closed] do
    Logger.error("tcp closed, disconnected")
    trace(data, :error_closed, error_message: "tcp closed, disconnected")
    {:next_state, :disconnected, data}
  end

  def handle_event(:info, {error, _socket, reason}, _state, data)
      when error in [:tcp_error, :ssl_error] do
    Logger.error("tcp closed, disconnected, error: #{inspect(reason)}")
    trace(data, :error_closed, error_message: "tcp closed, disconnected, error: #{inspect(reason)}")
    {:next_state, :disconnected, data}
  end

  def handle_event({:call, from}, :is_connected?, state, _data) do
    {:keep_state_and_data, [{:reply, from, state == :connected}]}
  end

  def handle_event(:cast, {:trace, pid, true}, state, data) when is_pid(pid) do
    if state == :connected, do: Kernel.send(pid, {:connected, self(), []})
    {:keep_state, %Data{data | tracer_pids: to_subscribe(data.tracer_pids, pid)}}
  end

  def handle_event(:cast, {:trace, pid, false}, _state, data) when is_pid(pid) do
    tracer_pids =
      Enum.reject(data.tracer_pids, fn {_ref, tpid} -> tpid == pid end)
      |> Map.new()

    {:keep_state, %Data{data | tracer_pids: tracer_pids}}
  end

  def handle_event(:info, {:DOWN, ref, :process, _pid, _reason}, _state, data) do
    {:keep_state, %Data{data | tracer_pids: Map.delete(data.tracer_pids, ref)}}
  end

  def handle_event(:cast, {:add_hook, name, function}, _state, data) do
    {:keep_state, %Data{data | hooks: Map.put(data.hooks, name, function)}}
  end

  def handle_event(:cast, {:del_hook, name}, _state, data) do
    {:keep_state, %Data{data | hooks: Map.delete(data.hooks, name)}}
  end

  def handle_event(:cast, :disconnect, _state, data) do
    xml_terminate = xml_terminate()
    data.tcp_handler.send(xml_terminate, get_socket(data))
    trace(data, :sent, packet: xml_terminate)
    data.tcp_handler.stop(get_socket(data))
    trace(data, :disconnected, [])
    data = %{data | tls_socket: nil, socket: nil, stream: nil}
    {:next_state, :disconnected, data}
  end

  def handle_event(type, content, state, data) do
    apply(__MODULE__, state, [type, content, data])
  end

  defp timeout_action(%Data{ping: false}), do: []
  defp timeout_action(%Data{ping: ping}), do: [{{:timeout, :ping}, ping, :send_ping}]

  defp get_socket(%Data{tls_socket: nil, socket: socket}), do: socket
  defp get_socket(%Data{tls_socket: tls_socket}), do: tls_socket
end

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

  ## Templates

  We have available the following templates:

  - `init` (domain): it sends the initial XML header. Requires the domain.
  - `starttls`: sends the stanza to init the TLS negotiation (WIP).
  - `auth` (user, password): send the auth stanza to the server.
  - `bind` (resource): establish the bind to a resource.
  - `session`: creates the session.
  - `presence`: sends a presence.
  - `message` (to, id, *kw_opts): build a message, it requires to specify
    different options. If we send `body: "hello"` then a body is created
    with that text as CDATA. We can also use `payload: "<body>Hello</body>"`
    to define the payload by ourselves. And even specify a `type`.
  - `register` (username, password): it sends the standard register
    stanza as is defined inside of the [XEP-0077](https://xmpp.org/extensions/xep-0077.html).

  ## Checks

  The checks are functions which check only the happy path, failing or raising
  an error if it's not finding what they need. We have defined the following
  checks:

  - `auth`: wait for the `success` stanza from the server.
  - `init`: wait for `stream:features` stanza and `bind` and `session` features inside.
  - `bind`: wait for the result IQ.
  - `presence`: wait for the available presence as an echo from the server.
  """
  use GenStateMachine, callback_mode: :handle_event_function
  require Logger

  import Kernel, except: [send: 2]

  alias Exampple.Router.Conn
  alias Exampple.Tls
  alias Exampple.Xml.Stream, as: XmlStream
  alias Exampple.Xml.Xmlel

  @default_tcp_handler Exampple.Tcp

  defp default_templates() do
    [
      init: &xml_init/1,
      starttls: fn -> "<starttls xmlns='urn:ietf:params:xml:ns:xmpp-tls'/>" end,
      auth: fn user, password ->
        base64 = Base.encode64(<<0, user::binary, 0, password::binary>>)

        "<auth xmlns='urn:ietf:params:xml:ns:xmpp-sasl' " <>
          "mechanism='PLAIN'>#{base64}</auth>"
      end,
      bind: fn resource ->
        "<iq type='set' id='bind3' xmlns='jabber:client'>" <>
          "<bind xmlns='urn:ietf:params:xml:ns:xmpp-bind'>" <>
          "<resource>#{resource}</resource></bind></iq>"
      end,
      session: fn ->
        "<iq type='set' id='session4'>" <>
          "<session xmlns='urn:ietf:params:xml:ns:xmpp-session'/></iq>"
      end,
      presence: fn -> "<presence/>" end,
      message: fn
        to, id, body: body_text ->
          "<message to='#{to}' id='#{id}' type='chat'><body>#{body_text}</body></message>"

        to, id, type: type, payload: payload ->
          "<message to='#{to}' id='#{id}' type='#{type}'>#{payload}</message>"
      end,
      iq: fn
        to, id, type, xmlns: xmlns ->
          "<iq to='#{to}' id='#{id}' type='#{type}'><query xmlns='#{xmlns}'/></iq>"

        to, id, type, payload: payload ->
          "<iq to='#{to}' id='#{id}' type='#{type}'>#{payload}</iq>"

        to, id, type, xmlns: xmlns, payload: payload ->
          "<iq to='#{to}' id='#{id}' type='#{type}'><query xmlns='#{xmlns}'>#{payload}</query></iq>"
      end,
      register: fn username, password ->
        "<iq id='reg1' type='set'>" <>
          "<query xmlns='jabber:iq:register'>" <>
          "<username>#{username}</username>" <>
          "<password>#{password}</password>" <>
          "</query></iq>"
      end
    ]
  end

  defp default_checks() do
    [
      auth: fn pname ->
        %Conn{stanza_type: "success"} = get_conn(pname)
      end,
      starttls: fn pname ->
        %Conn{stanza_type: "proceed"} = get_conn(pname)
      end,
      init: fn pname ->
        %Conn{
          stanza_type: "stream:features",
          stanza: stanza,
          xmlns: "urn:ietf:params:xml:ns:xmpp-bind"
        } = conn = get_conn(pname)

        [%Xmlel{}] = stanza["bind"]
        [%Xmlel{}] = stanza["session"]
        conn
      end,
      bind: fn pname ->
        %Conn{
          stanza_type: "iq",
          type: "result",
          xmlns: "urn:ietf:params:xml:ns:xmpp-bind"
        } = get_conn(pname)
      end,
      presence: fn pname ->
        %Conn{
          stanza_type: "presence",
          type: "available"
        } = get_conn(pname)
      end
    ]
  end

  defmodule Data do
    @moduledoc false
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
              send_pid: nil,
              templates: [],
              checks: [],
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
  """
  def start_link(name \\ __MODULE__, args) do
    GenStateMachine.start_link(__MODULE__, [name, self(), args], name: name)
  end

  @doc """
  Send a message to the client process to start the connection. Optionally,
  we can specify the `name` of the process where to connect, by default this
  is the value provided by `__MODULE__`.
  """
  @spec connect() :: :ok
  @spec connect(atom()) :: :ok
  def connect(name \\ __MODULE__) do
    :ok = GenStateMachine.cast(name, :connect)
  end

  @doc """
  Upgrade a connection as TLS.
  """
  @spec upgrade_tls() :: :ok
  @spec upgrade_tls(atom()) :: :ok
  def upgrade_tls(name \\ __MODULE__) do
    :ok = GenStateMachine.cast(name, :upgrade_tls)
  end

  @doc """
  Send a message to the client process identified by `name` as PID
  or registered process to stop the connection. The `name` parameter
  is optional, by default it's set to `__MODULE__`.
  """
  @spec disconnect() :: :ok
  def disconnect(name \\ __MODULE__) do
    :ok = GenStateMachine.cast(name, :disconnect)
  end

  @doc """
  Ask to the process about whether the connection is active. The checks are based
  on the process relanted to the passed `name` (it must be a registered name), the
  PID should be valid and alive, and then we ask to the client if it's connected.
  If no parameter is provided it is `__MODULE__`.
  """
  def is_connected?(name \\ __MODULE__) do
    with pid <- Process.whereis(name),
         true <- is_pid(pid),
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
  Use a template registered inside of the client. This let us to
  trigger faster stanzas when we are working from the shell. But
  also reduce the amount of code when we are developing tests.

  The `template` parameter is an atom, the key for the keyword
  list of templates stored inside of the process. The `args` are
  the arguments passed to the function template. Finally the `name`
  is the name of the process where the request will be sent.
  """
  @spec send_template(atom(), [any()], atom() | pid()) :: :ok | :not_found
  def send_template(template, args \\ [], name \\ __MODULE__)
      when is_atom(template) and is_list(args) do
    case GenStateMachine.call(name, {:get_template, template}) do
      {:ok, xml_fn} ->
        xml_fn
        |> apply(args)
        |> send(name)

      :error ->
        :not_found
    end
  end

  @doc """
  Use a check registered inside of the client verifying if the incoming
  stanzas are passing the checks defined by the anonymous function. In
  the same way as the `send_template/3` function it provides to the
  developer the ability to write better and shorter tests.

  We are providing the `template` name for the check, optionally some `args`
  if the check requires it and the `name` of the process for the client,
  by default it will be `__MODULE__`.

  The return of the check should be a map, if you return an struct it will
  be inserted inside of an empty map using the name of the struct as name.
  For example, returning a `%Conn{}` it will result in a `%{"conn" => %Conn{}}`.
  """
  @spec check!(atom(), [any()], atom() | pid()) :: map()
  def check!(template, args \\ [], name \\ __MODULE__)
      when is_atom(template) and is_list(args) do
    case GenStateMachine.call(name, {:get_check, template}) do
      {:ok, check_fn} ->
        case apply(check_fn, args) do
          %struct{} = result -> %{String.downcase(to_string(struct)) => result}
          %{} = result -> result
          _ -> %{}
        end

      :error ->
        raise "check #{template} for #{name} not found!"
    end
  end

  @doc """
  Adds a template to be in use by the process when we call `send_template/2`
  or `send_template/3`. The `name` is the name or PID for the process, the
  `key` is the name we will use storing the template and `fun` is the
  function which will generate the stanza.
  """
  @spec add_template(atom(), atom(), (... -> String.t())) :: :ok
  def add_template(name \\ __MODULE__, key, fun) do
    :ok = GenStateMachine.cast(name, {:add_template, key, fun})
  end

  @doc """
  Adds a check to be in use by the process when we call `check/2` or
  `check/3`. The `name` is the name or PID for the process, the `key`
  is the name we will use storing the template and `fun` is the function
  which will check the incoming stanza returning true or false if the
  check is passed.
  """
  @spec add_check(atom(), atom(), (... -> boolean())) :: :ok
  def add_check(name \\ __MODULE__, key, fun) do
    :ok = GenStateMachine.cast(name, {:add_check, key, fun})
  end

  @doc """
  Waits for an incoming connection / stanza which will be sent from
  the client process. It only works if we are using this function
  from the process which execute the `start_link` function or if
  we passed the PID of the current process as the `name` parameter.
  Optionally, we can configure a `timeout`, by default it's set to
  5 seconds.
  """
  def get_conn(name, timeout \\ 5_000) do
    receive do
      {:conn, ^name, packet} -> packet
    after
      timeout -> :timeout
    end
  end

  @doc """
  Same as `get_conn/2` but we are waiting for a specific number
  of stanzas to be received indicated by `num` parameter. We have
  to indicate the `name` for the process where we are going to be
  connected.

  Optionally, we can configure a `timeout`, by default it's set to
  5 seconds.
  """
  def get_conns(name, num, timeout \\ 5_000) do
    receive do
      {:conn, ^name, packet} when num > 1 ->
        [packet | get_conns(num - 1, timeout)]

      {:conn, ^name, packet} when num == 1 ->
        [packet]
    after
      timeout -> [:timeout]
    end
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
      templates: default_templates(),
      checks: default_checks(),
      send_pid: pid
    }

    {:ok, :disconnected, state_data}
  end

  @doc false
  def disconnected(:cast, :connect, data) do
    case data.tcp_handler.start(data.host, data.port) do
      {:ok, socket} ->
        stream = XmlStream.new()
        xml_init = xml_init(data.domain)
        data.tcp_handler.send(xml_init, socket)
        Logger.info("(#{data.name}) sent: #{IO.ANSI.yellow()}#{xml_init}#{IO.ANSI.reset()}")
        data = %Data{data | socket: socket, stream: stream}
        {:next_state, :connected, data, timeout_action(data)}

      error ->
        Logger.error("connect error #{data.host}:#{data.port}: #{inspect(error)}")
        :keep_state_and_data
    end
  end

  def disconnected(:cast, {:send, _packet}, _data) do
    Logger.error("cannot process sent, we're still disconnected!")
    :keep_state_and_data
  end

  def disconnected(:cast, :upgrade_tls, _data) do
    Logger.error("cannot process upgrade TLS, we're still disconnected!")
    :keep_state_and_data
  end

  def disconnected({:timeout, :ping}, :send_ping, _data) do
    :keep_state_and_data
  end

  @doc false
  def connected(:info, {:xmlelement, xmlel}, data) do
    conn = Conn.new(xmlel)
    Kernel.send(data.send_pid, {:conn, data.name, conn})

    Logger.info(
      "(#{data.name}) received: #{IO.ANSI.green()}#{to_string(xmlel)}#{IO.ANSI.reset()}"
    )

    data = %Data{data | stream: XmlStream.new()}
    {:keep_state, data}
  end

  def connected(:info, {:xmlstreamstart, "stream:stream", _attrs}, data) do
    data = %Data{data | stream: XmlStream.new()}
    {:keep_state, data, timeout_action(data)}
  end

  def connected(:info, {:xmlstreamstart, _name, _attrs}, data) do
    {:keep_state_and_data, timeout_action(data)}
  end

  def connected(:cast, {:send, packet}, data) when is_binary(packet) do
    data.tcp_handler.send(packet, get_socket(data))
    Logger.info("(#{data.name}) sent: #{IO.ANSI.yellow()}#{packet}#{IO.ANSI.reset()}")
    :keep_state_and_data
  end

  def connected(:cast, :upgrade_tls, %Data{socket: socket, tls_socket: nil} = data) do
    case Tls.start(socket) do
      {:ok, tls_socket} ->
        stream = XmlStream.new()
        xml_init = xml_init(data.domain)
        Tls.send(xml_init, tls_socket)
        Logger.info("(#{data.name}) sent: #{IO.ANSI.yellow()}#{xml_init}#{IO.ANSI.reset()}")
        {:keep_state, %Data{data | stream: stream, tls_socket: tls_socket, tcp_handler: Tls}}

      {:error, reason} ->
        Logger.error("start TLS failed due to: #{inspect(reason)}")
        :keep_state_and_data
    end
  end

  def connected(:cast, :upgrade_tls, _data) do
    Logger.warn("TLS was already connected!")
    :keep_state_and_data
  end

  def connected({:timeout, :ping}, :send_ping, data) do
    data.tcp_handler.send("\n", get_socket(data))
    Logger.debug("sent (ping)")
    {:keep_state_and_data, timeout_action(data)}
  end

  @impl GenStateMachine
  @doc false
  def terminate(_reason, :disconnected, _data), do: :ok

  def terminate(_reason, _state, data) do
    data.tcp_handler.send(xml_terminate(), get_socket(data))
    Logger.info("(#{data.name}) sent: #{IO.ANSI.yellow()}#{xml_terminate()}#{IO.ANSI.reset()}")
    data.tcp_handler.stop(get_socket(data))
    :ok
  end

  @impl GenStateMachine
  @doc false
  def handle_event(:info, {type, _socket, packet}, _state, data) when type in [:tcp, :ssl] do
    Logger.info("(#{data.name}) received (packet): #{IO.ANSI.cyan()}#{packet}#{IO.ANSI.reset()}")
    stream = XmlStream.parse(data.stream, packet)
    {:keep_state, %Data{data | stream: stream}}
  end

  def handle_event(:info, {closed, _socket}, _state, data)
      when closed in [:tcp_closed, :ssl_closed] do
    Logger.error("tcp closed, disconnected")
    {:stop, :normal, data}
  end

  def handle_event(:info, {error, _socket, reason}, _state, data)
      when error in [:tcp_error, :ssl_error] do
    Logger.error("tcp closed, disconnected, error: #{inspect(reason)}")
    {:stop, :normal, data}
  end

  def handle_event(:cast, {:add_template, key, template}, _state, data) do
    templates = Keyword.put(data.templates, key, template)
    {:keep_state, %Data{data | templates: templates}}
  end

  def handle_event(:cast, {:add_check, key, check}, _state, data) do
    checks = Keyword.put(data.checks, key, check)
    {:keep_state, %Data{data | checks: checks}}
  end

  def handle_event({:call, from}, {:get_template, template}, _state, data) do
    reply = Keyword.fetch(data.templates, template)
    {:keep_state_and_data, [{:reply, from, reply}]}
  end

  def handle_event({:call, from}, {:get_check, check}, _state, data) do
    reply = Keyword.fetch(data.checks, check)
    {:keep_state_and_data, [{:reply, from, reply}]}
  end

  def handle_event({:call, from}, :is_connected?, state, _data) do
    {:keep_state_and_data, [{:reply, from, state == :connected}]}
  end

  def handle_event(:cast, :disconnect, _state, data) do
    data.tcp_handler.send(xml_terminate(), get_socket(data))
    Logger.info("(#{data.name}) sent: #{IO.ANSI.yellow()}#{xml_terminate()}#{IO.ANSI.reset()}")
    data.tcp_handler.stop(get_socket(data))
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

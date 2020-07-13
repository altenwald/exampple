defmodule Exampple.Client do
  use GenStateMachine, callback_mode: :handle_event_function
  require Logger

  import Kernel, except: [send: 2]

  alias Exampple.Router.Conn
  alias Exampple.Router
  alias Exampple.Xml.Stream, as: XmlStream

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
      register: fn username, password, phone ->
        "<iq id='reg1' type='set'>" <>
          "<query xmlns='jabber:iq:register'>" <>
          "<username>#{username}</username>" <>
          "<password>#{password}</password>" <>
          "<phone>#{phone}</phone>" <>
          "</query></iq>"
      end
    ]
  end

  defmodule Data do
    defstruct socket: nil,
              stream: nil,
              host: nil,
              domain: nil,
              port: 5280,
              trimmed: false,
              set_from: false,
              ping: false,
              tcp_handler: Tcp,
              send_pid: nil,
              templates: []
  end

  defp xml_init(domain) do
    "<?xml version='1.0' encoding='UTF-8'?>" <>
      "<stream:stream to='#{domain}' " <>
      "xmlns='jabber:client' " <>
      "xmlns:stream='http://etherx.jabber.org/streams' " <>
      "version='1.0'>"
  end

  defp xml_terminate(), do: "</stream:stream>"

  def start_link(args) do
    start_link(__MODULE__, args)
  end

  def start_link(name, args) do
    GenStateMachine.start_link(__MODULE__, [self(), args], name: name)
  end

  @spec connect() :: :ok
  def connect() do
    :ok = GenStateMachine.cast(__MODULE__, :connect)
  end

  @spec disconnect() :: :ok
  def disconnect() do
    :ok = GenStateMachine.cast(__MODULE__, :disconnect)
  end

  @spec stop() :: :ok
  def stop() do
    :ok = GenStateMachine.stop(__MODULE__)
  end

  def starttls() do
    send(:starttls, [])
  end

  @spec send(binary | Conn.t()) :: :ok
  def send(data) when is_binary(data) do
    GenStateMachine.cast(__MODULE__, {:send, data})
  end

  def send(%Conn{response: response} = conn) when response != nil do
    data = to_string(conn.response)
    GenStateMachine.cast(__MODULE__, {:send, data})
  end

  def send(template, args) do
    case GenServer.call(__MODULE__, {:get_template, template}) do
      {:ok, xml_fn} ->
        xml_fn
        |> apply(args)
        |> send()

      :error ->
        :not_found
    end
  end

  def add_template(key, fun) do
    :ok = GenStateMachine.cast(__MODULE__, {:add_template, key, fun})
  end

  def get_conn(timeout \\ 5_000) do
    receive do
      {:packet, packet} -> packet
    after
      timeout -> nil
    end
  end

  @impl GenStateMachine
  def init([pid, %{host: host, port: port, domain: domain} = cfg]) do
    state_data = %Data{
      stream: nil,
      host: host,
      domain: domain,
      port: port,
      trimmed: Map.get(cfg, :trimmed, false),
      set_from: Map.get(cfg, :set_from, false),
      ping: Map.get(cfg, :ping, false),
      tcp_handler: Map.get(cfg, :tcp_handler, @default_tcp_handler),
      templates: default_templates(),
      send_pid: pid
    }

    {:ok, :disconnected, state_data}
  end

  def disconnected(:cast, :connect, data) do
    case data.tcp_handler.start(data.host, data.port) do
      {:ok, socket} ->
        stream = XmlStream.new()
        xml_init = xml_init(data.domain)
        data.tcp_handler.send(xml_init, socket)
        Logger.info("sent: #{IO.ANSI.yellow()}#{xml_init}#{IO.ANSI.reset()}")
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

  def disconnected({:timeout, :ping}, :send_ping, _data) do
    :keep_state_and_data
  end

  def connected(:info, {:xmlelement, xmlel}, data) do
    conn = Conn.new(xmlel)
    Kernel.send(data.send_pid, {:conn, conn})
    Logger.info("received: #{IO.ANSI.green()}#{to_string(xmlel)}#{IO.ANSI.reset()}")
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
    data.tcp_handler.send(packet, data.socket)
    Logger.info("sent: #{IO.ANSI.yellow()}#{packet}#{IO.ANSI.reset()}")
    :keep_state_and_data
  end

  def connected({:timeout, :ping}, :send_ping, data) do
    data.tcp_handler.send("\n", data.socket)
    Logger.debug("sent (ping)")
    {:keep_state_and_data, timeout_action(data)}
  end

  @impl GenStateMachine
  def terminate(_reason, :disconnected, _data), do: :ok

  def terminate(_reason, _state, data) do
    data.tcp_handler.send(xml_terminate(), data.socket)
    Logger.info("sent: #{IO.ANSI.yellow()}#{xml_terminate()}#{IO.ANSI.reset()}")
    data.tcp_handler.stop(data.socket)
    :ok
  end

  @impl GenStateMachine
  def handle_event(:info, {:tcp, _socket, packet}, _state, data) do
    Logger.info("received (packet): #{IO.ANSI.cyan()}#{packet}#{IO.ANSI.reset()}")
    stream = XmlStream.parse(data.stream, packet)
    {:keep_state, %Data{data | stream: stream}}
  end

  def handle_event(:info, {:tcp_closed, _socket}, _state, data) do
    Logger.error("tcp closed, disconnected")
    {:stop, :normal, data}
  end

  def handle_event(:info, {:tcp_error, _socket, reason}, _state, data) do
    Logger.error("tcp closed, disconnected, error: #{inspect(reason)}")
    {:stop, :normal, data}
  end

  def handle_event(:cast, {:add_template, key, template}, _state, data) do
    templates = Keyword.put(data.templates, key, template)
    {:keep_state, %Data{data | templates: templates}}
  end

  def handle_event({:call, from}, {:get_template, template}, _state, data) do
    reply = Keyword.fetch(data.templates, template)
    {:keep_state_and_data, [{:reply, from, reply}]}
  end

  def handle_event(:cast, :disconnect, _state, data) do
    data.tcp_handler.send(xml_terminate(), data.socket)
    Logger.info("sent: #{IO.ANSI.yellow()}#{xml_terminate()}#{IO.ANSI.reset()}")
    data.tcp_handler.stop(data.socket)
    data = %{data | socket: nil, stream: nil}
    {:next_state, :disconnected, data}
  end

  def handle_event(type, content, state, data) do
    apply(__MODULE__, state, [type, content, data])
  end

  defp timeout_action(%Data{ping: false}), do: []
  defp timeout_action(%Data{ping: ping}), do: [{{:timeout, :ping}, ping, :send_ping}]
end

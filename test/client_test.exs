defmodule Exampple.ClientTest do
  use ExUnit.Case, async: false

  require Exampple.Client
  require Logger

  import Exampple.Xml.Xmlel
  import Exampple.Router.ConnCase.Client

  alias Exampple.{Client, DummyTcpClient}
  alias Exampple.Router.Conn
  alias Exampple.Xmpp.{Envelope, Stanza}

  @name Exampple.Client

  describe "connectivity" do
    test "starting" do
      assert {:ok, _pid} =
               Client.start_link(%{
                 host: "example.com",
                 port: 5222,
                 domain: "example.com",
                 tcp_handler: DummyTcpClient
               })

      assert {:disconnected, %Client.Data{}} = :sys.get_state(Client)
      Client.stop()
    end

    test "connecting" do
      assert {:ok, pid} =
               Client.start_link(%{
                 host: "example.com",
                 port: 5222,
                 domain: "example.com",
                 tcp_handler: DummyTcpClient
               })

      Client.connect()
      Client.wait_for_connected()
      assert Client.is_connected?()
      assert {:connected, %Client.Data{}} = :sys.get_state(Client)
      assert nil == DummyTcpClient.sent()
      assert :ok == Client.disconnect()
      refute Client.is_connected?()
      Client.stop()
    end
  end

  describe "sending stanzas to the server" do
    setup do
      assert {:ok, pid} =
               Client.start_link(%{
                 host: "example.com",
                 port: 5222,
                 domain: "example.com",
                 tcp_handler: DummyTcpClient
               })

      Client.connect()
      assert :ok == Client.wait_for_connected()
      DummyTcpClient.subscribe()
      [pid: pid]
    end

    test "message (binary)" do
      stanza = ~x[<message to='aaa@example.com'/>]
      assert :ok == Client.send(to_string(stanza))
      assert stanza == DummyTcpClient.wait_for_sent_xml(500)
    end

    test "message (conn)" do
      conn =
        ~x[<message to='aaa@example.com'/>]
        |> Conn.new()
        |> Stanza.message_resp([])

      assert :ok == Client.send(conn)

      resp = ~x[<message from='aaa@example.com'/>]
      assert resp == DummyTcpClient.wait_for_sent_xml(500)
    end
  end

  describe "receiving stanzas from the server" do
    setup do
      assert {:ok, pid} =
               Client.start_link(%{
                 host: "example.com",
                 port: 5222,
                 domain: "example.com",
                 tcp_handler: DummyTcpClient
               })

      Client.connect()
      assert :ok == Client.wait_for_connected()
      DummyTcpClient.subscribe()
      [pid: pid]
    end

    test "message" do
      assert :ok == DummyTcpClient.received("<message to='aaa@example.com'/>")
      stanza = ~x[<message to='aaa@example.com'/>]
      assert %Conn{stanza: ^stanza} = Client.get_conn(@name)
    end
  end

  describe "templates" do
    setup do
      assert {:ok, pid} =
               Client.start_link(%{
                 host: "example.com",
                 port: 5222,
                 domain: "example.com",
                 tcp_handler: DummyTcpClient
               })

      Client.connect()
      assert :ok == Client.wait_for_connected()
      DummyTcpClient.subscribe()
      [pid: pid]
    end

    test "add template" do
      Client.add_template(:custom, fn -> "<custom/>" end)
      Client.send_template(:custom)
      assert ~x[<custom/>] == DummyTcpClient.wait_for_sent_xml(500)
    end

    test "use predefined template" do
      Client.send_template(:auth, ["user", "pass"])
      assert ~x[
        <auth mechanism='PLAIN' xmlns='urn:ietf:params:xml:ns:xmpp-sasl'>
          AHVzZXIAcGFzcw==
        </auth>
      ] == DummyTcpClient.wait_for_sent_xml(500)
      Client.send_template(:bind, ["res"])
      assert ~x[
        <iq type='set' id='bind3' xmlns='jabber:client'>
          <bind xmlns='urn:ietf:params:xml:ns:xmpp-bind'>
            <resource>res</resource>
          </bind>
        </iq>
      ] == DummyTcpClient.wait_for_sent_xml(500)
      Client.send_template(:session)
      assert ~x[
        <iq type='set' id='session4'>
          <session xmlns='urn:ietf:params:xml:ns:xmpp-session'/>
        </iq>
      ] == DummyTcpClient.wait_for_sent_xml(500)
      Client.send_template(:presence)
      assert ~x[<presence/>] == DummyTcpClient.wait_for_sent_xml(500)
      Client.send_template(:message, [ "alice@example.com", "msg1", [body: "text"] ])
      assert ~x[
        <message to='alice@example.com' id='msg1' type='chat'>
          <body>text</body>
        </message>
      ] == DummyTcpClient.wait_for_sent_xml(500)
      Client.send_template(:message, [ "alice@example.com", "msg2", [type: "chat", payload: "<no-text/>"] ])
      assert ~x[
        <message to='alice@example.com' id='msg2' type='chat'>
          <no-text/>
        </message>
      ] == DummyTcpClient.wait_for_sent_xml(500)
    end
  end

  describe "checks" do
    setup do
      assert {:ok, pid} =
               Client.start_link(%{
                 host: "example.com",
                 port: 5222,
                 domain: "example.com",
                 tcp_handler: DummyTcpClient
               })

      Client.connect()
      assert :ok == Client.wait_for_connected()
      DummyTcpClient.subscribe()
      [pid: pid]
    end

    test "add check" do
      Client.add_check(:msg, fn -> %{ check!: true } end)
      assert %{ check!: true } == Client.check!(:msg)
    end

    test "predefined checks" do
      assert :ok = DummyTcpClient.received("<success/>")
      assert %{} = Client.check!(:auth, [@name])
      assert :ok = DummyTcpClient.received("<proceed/>")
      assert %{} = Client.check!(:starttls, [@name])
      assert :ok = DummyTcpClient.received("<stream:features><bind xmlns='urn:ietf:params:xml:ns:xmpp-bind'/><session xmlns='urn:xmpp:sm:3'/></stream:features>")
      assert %{"elixir.exampple.router.conn" => %Conn{}} = Client.check!(:init, [@name])
    end

    test "no good return" do
      Client.add_check(:msg, fn -> :check! end)
      assert %{} = empty_map = Client.check!(:msg)
      assert map_size(empty_map) == 0
    end

    test "missing check" do
      assert_raise Exampple.Client.CheckException, fn ->
        Client.check!(:msgX)
      end
    end
  end
end

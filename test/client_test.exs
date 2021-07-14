defmodule Exampple.ClientTest do
  use ExUnit.Case, async: false

  require Exampple.Client
  require Logger

  import Exampple.Xml.Xmlel
  import Exampple.Router.ConnCase.Client

  alias Exampple.{Client, DummyTcpClient}
  alias Exampple.Router.Conn
  alias Exampple.Xmpp.{Envelope, Stanza}

  describe "connectivity" do
    test "starting" do
      pname = :starting_test
      assert {:ok, _pid} =
               Client.start_link(pname, %{
                 host: "example.com",
                 port: 5222,
                 domain: "example.com",
                 tcp_handler: DummyTcpClient
               })

      assert {:disconnected, %Client.Data{}} = :sys.get_state(pname)
      Client.stop(pname)
    end

    test "connecting" do
      pname = :connecting_test
      assert {:ok, pid} =
               Client.start_link(pname, %{
                 host: "example.com",
                 port: 5222,
                 domain: "example.com",
                 tcp_handler: DummyTcpClient
               })

      Client.connect(pname)
      Client.wait_for_connected(pname)
      assert Client.is_connected?(pname)
      assert {:connected, %Client.Data{}} = :sys.get_state(pname)
      assert nil == DummyTcpClient.sent()
      assert :ok == Client.disconnect(pname)
      refute Client.is_connected?(pname)
      Client.stop(pname)
    end
  end

  describe "sending stanzas to the server" do
    setup do
      pname = :sending_test
      assert {:ok, pid} =
               Client.start_link(pname, %{
                 host: "example.com",
                 port: 5222,
                 domain: "example.com",
                 tcp_handler: DummyTcpClient
               })

      Client.connect(pname)
      assert :ok == Client.wait_for_connected(pname)
      DummyTcpClient.subscribe()
      on_exit(fn ->
        if Client.is_connected?(pname) do
          Client.stop(pname)
        end
      end)
      [pid: pid, pname: pname]
    end

    test "message (binary)", %{pname: pname} do
      stanza = ~x[<message to='aaa@example.com'/>]
      assert :ok == Client.send(to_string(stanza), pname)
      assert stanza == DummyTcpClient.wait_for_sent_xml(500)
    end

    test "message (conn)", %{pname: pname} do
      conn =
        ~x[<message to='aaa@example.com'/>]
        |> Conn.new()
        |> Stanza.message_resp([])

      assert :ok == Client.send(conn, pname)

      resp = ~x[<message from='aaa@example.com'/>]
      assert resp == DummyTcpClient.wait_for_sent_xml(500)
    end
  end

  describe "receiving stanzas from the server" do
    setup do
      pname = :receiving_test
      assert {:ok, pid} =
               Client.start_link(pname, %{
                 host: "example.com",
                 port: 5222,
                 domain: "example.com",
                 tcp_handler: DummyTcpClient
               })

      Client.connect(pname)
      assert :ok == Client.wait_for_connected(pname)
      DummyTcpClient.subscribe()
      on_exit(fn ->
        if Client.is_connected?(pname) do
          Client.stop(pname)
        end
      end)
      [pid: pid, pname: pname]
    end

    test "message", %{pname: pname} do
      assert :ok == DummyTcpClient.received("<message to='aaa@example.com'/>")
      stanza = ~x[<message to='aaa@example.com'/>]
      assert %Conn{stanza: ^stanza} = Client.get_conn(pname)
    end
  end

  describe "templates" do
    setup do
      pname = :templates_test
      assert {:ok, pid} =
               Client.start_link(pname, %{
                 host: "example.com",
                 port: 5222,
                 domain: "example.com",
                 tcp_handler: DummyTcpClient
               })

      Client.connect(pname)
      assert :ok == Client.wait_for_connected(pname)
      DummyTcpClient.subscribe()
      on_exit(fn ->
        if Client.is_connected?(pname) do
          Client.stop(pname)
        end
      end)
      [pid: pid, pname: pname]
    end

    test "add template", %{pname: pname} do
      Client.add_template(pname, :custom, fn -> "<custom/>" end)
      Client.send_template(:custom, [], pname)
      assert ~x[<custom/>] == DummyTcpClient.wait_for_sent_xml(500)
    end

    test "use predefined template", %{pname: pname} do
      Client.send_template(:auth, ["user", "pass"], pname)
      assert ~x[
        <auth mechanism='PLAIN' xmlns='urn:ietf:params:xml:ns:xmpp-sasl'>
          AHVzZXIAcGFzcw==
        </auth>
      ] == DummyTcpClient.wait_for_sent_xml(500)
      Client.send_template(:bind, ["res"], pname)
      assert ~x[
        <iq type='set' id='bind3' xmlns='jabber:client'>
          <bind xmlns='urn:ietf:params:xml:ns:xmpp-bind'>
            <resource>res</resource>
          </bind>
        </iq>
      ] == DummyTcpClient.wait_for_sent_xml(500)
      Client.send_template(:session, [], pname)
      assert ~x[
        <iq type='set' id='session4'>
          <session xmlns='urn:ietf:params:xml:ns:xmpp-session'/>
        </iq>
      ] == DummyTcpClient.wait_for_sent_xml(500)
      Client.send_template(:presence, [], pname)
      assert ~x[<presence/>] == DummyTcpClient.wait_for_sent_xml(500)
      Client.send_template(:message, ["alice@example.com", "msg1", [body: "text"]], pname)
      assert ~x[
        <message to='alice@example.com' id='msg1' type='chat'>
          <body>text</body>
        </message>
      ] == DummyTcpClient.wait_for_sent_xml(500)

      Client.send_template(:message, [
        "alice@example.com",
        "msg2",
        [type: "chat", payload: "<no-text/>"]
      ], pname)

      assert ~x[
        <message to='alice@example.com' id='msg2' type='chat'>
          <no-text/>
        </message>
      ] == DummyTcpClient.wait_for_sent_xml(500)
    end
  end

  describe "checks" do
    setup do
      pname = :checks_test
      assert {:ok, pid} =
               Client.start_link(pname, %{
                 host: "example.com",
                 port: 5222,
                 domain: "example.com",
                 tcp_handler: DummyTcpClient
               })

      Client.connect(pname)
      assert :ok == Client.wait_for_connected(pname)
      DummyTcpClient.subscribe()
      on_exit(fn ->
        if Client.is_connected?(pname) do
          Client.stop(pname)
        end
      end)
      [pid: pid, pname: pname]
    end

    test "add check", %{pname: pname} do
      Client.add_check(pname, :msg, fn -> %{check!: true} end)
      assert %{check!: true} == Client.check!(:msg, [], pname)
    end

    test "predefined checks", %{pname: pname} do
      assert :ok = DummyTcpClient.received("<success/>")
      assert %{} = Client.check!(:auth, [pname], pname)
      assert :ok = DummyTcpClient.received("<proceed/>")
      assert %{} = Client.check!(:starttls, [pname], pname)

      assert :ok =
               DummyTcpClient.received(
                 "<stream:features><bind xmlns='urn:ietf:params:xml:ns:xmpp-bind'/><session xmlns='urn:xmpp:sm:3'/></stream:features>"
               )

      assert %{"elixir.exampple.router.conn" => %Conn{}} = Client.check!(:init, [pname], pname)
    end

    test "no good return", %{pname: pname} do
      Client.add_check(pname, :msg, fn -> :check! end)
      assert %{} = empty_map = Client.check!(:msg, [], pname)
      assert map_size(empty_map) == 0
    end

    test "missing check", %{pname: pname} do
      assert_raise Exampple.Client.CheckException, fn ->
        Client.check!(:msgX, [], pname)
      end
    end
  end
end

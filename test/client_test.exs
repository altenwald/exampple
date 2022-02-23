defmodule Exampple.ClientTest do
  use ExUnit.Case, async: false

  require Logger

  import Exampple.Xml.Xmlel
  import Exampple.Router.ConnCase.Client

  alias Exampple.{Client, DummyTcpClient, Template}
  alias Exampple.Router.Conn
  alias Exampple.Xmpp.Stanza

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

      assert {:ok, _pid} =
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
      assert_stanza_receive(stanza)
    end

    test "message (conn)", %{pname: pname} do
      conn =
        ~x[<message to='aaa@example.com'/>]
        |> Conn.new()
        |> Stanza.message_resp([])

      assert :ok == Client.send(conn, pname)

      resp = ~x[<message from='aaa@example.com'/>]
      assert_stanza_receive(resp)
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
      parent = self()

      Client.add_hook(pname, "received", fn conn ->
        send(parent, to_string(conn.stanza))
        conn
      end)

      on_exit(fn ->
        if Client.is_connected?(pname) do
          Client.stop(pname)
        end
      end)

      [pid: pid, pname: pname]
    end

    test "message", %{pname: _pname} do
      stanza = ~x[<message to='aaa@example.com'/>]
      assert :ok == client_received(stanza)
      assert_stanza_receive(stanza)
    end

    test "chunks stanzas", %{pname: _pname} do
      assert :ok ==
               client_received(
                 "<iq type='get' from='test.example.com' to='User@example.com/res1' id='1'>" <>
                   "<query xmlns='jabber:iq:ping'/>" <>
                   "</iq><iq type='get' from='test.example.com' to='User@example.com/res1' id='2'>" <>
                   "<query xmlns='jabbe"
               )

      Process.sleep(100)
      assert :ok == client_received("r:iq:ping'/></iq>")

      stanza1 = ~x[
        <iq from="test.example.com" id="1" to="User@example.com/res1" type="get">
          <query xmlns="jabber:iq:ping"/>
        </iq>
      ]

      stanza2 = ~x[
        <iq from="test.example.com" id="2" to="User@example.com/res1" type="get">
          <query xmlns="jabber:iq:ping"/>
        </iq>
      ]
      assert_all_stanza_receive([stanza1, stanza2])
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
      Template.init()

      on_exit(fn ->
        if Client.is_connected?(pname) do
          Client.stop(pname)
        end
      end)

      [pid: pid, pname: pname]
    end

    test "add template", %{pname: pname} do
      Template.put(:custom, "<custom/>")
      packet = Template.render!(:custom, [])
      Client.send(packet, pname)
      assert_stanza_receive(~x[<custom/>])
    end

    test "use predefined template", %{pname: pname} do
      Template.put(
        :auth,
        "<auth mechanism='PLAIN' xmlns='urn:ietf:params:xml:ns:xmpp-sasl'>%{pass}</auth>"
      )

      Template.put(
        :bind,
        "<iq type='set' id='bind3' xmlns='jabber:client'><bind xmlns='urn:ietf:params:xml:ns:xmpp-bind'><resource>%{res}</resource></bind></iq>"
      )

      Template.put(
        :session,
        "<iq type='set' id='session4'><session xmlns='urn:ietf:params:xml:ns:xmpp-session'/></iq>"
      )

      Template.put(:presence, "<presence/>")

      pass = Base.encode64(<<0, "user", 0, "pass">>)
      packet = Template.render!(:auth, pass: pass)
      Client.send(packet, pname)
      assert_stanza_receive(~x[
        <auth mechanism='PLAIN' xmlns='urn:ietf:params:xml:ns:xmpp-sasl'>
          AHVzZXIAcGFzcw==
        </auth>
      ])

      packet = Template.render!(:bind, res: "res")
      Client.send(packet, pname)
      assert_stanza_receive(~x[
        <iq type='set' id='bind3' xmlns='jabber:client'>
          <bind xmlns='urn:ietf:params:xml:ns:xmpp-bind'>
            <resource>res</resource>
          </bind>
        </iq>
      ])

      packet = Template.render!(:session)
      Client.send(packet, pname)
      assert_stanza_receive(~x[
        <iq type='set' id='session4'>
          <session xmlns='urn:ietf:params:xml:ns:xmpp-session'/>
        </iq>
      ])

      packet = Template.render!(:presence)
      Client.send(packet, pname)
      assert_stanza_receive(~x[<presence/>])
    end
  end
end

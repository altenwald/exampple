defmodule Exampple.ClientTest do
  use ExUnit.Case, async: false

  import Exampple.Xml.Xmlel
  import Exampple.Router.ConnCase.Client

  alias Exampple.{Client, DummyTcpClient}
  alias Exampple.Router.Conn
  alias Exampple.Xmpp.{Envelope, Stanza}

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
      assert {:connected, %Client.Data{}} = :sys.get_state(Client)
      assert nil == DummyTcpClient.sent()
      Client.stop()
    end
  end

  describe "templates" do
    test "add template" do
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
      Client.add_template(:custom, fn -> "<custom/>" end)
      Client.send_template(:custom)
      assert ~x[<custom/>] == DummyTcpClient.wait_for_sent_xml(500)
      Client.stop()
    end
  end
end

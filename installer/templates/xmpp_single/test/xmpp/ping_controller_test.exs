defmodule <%= app_module %>.Xmpp.PingControllerTest do
  use Exampple.Router.ConnCase
  import Exampple.Xml.Xmlel, only: [sigil_x: 2]

  describe "ping: " do
    test "send and receive" do
      component_received ~x[
        <iq type='get'
            id='1'
            from='user-id@localhost/res'
            to='comp.example.com'>
          <query xmlns='urn:xmpp:ping'/>
        </iq>
      ]

      assert_stanza_receive ~x[
        <iq type='result'
            id='1'
            from='comp.example.com'
            to='user-id@localhost/res'/>
      ]
    end
  end
end

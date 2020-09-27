defmodule <%= app_module %>.Xmpp.ErrorControllerTest do
  use Exampple.Router.ConnCase

  describe "error: " do
    test "feature not implemented" do
      component_receive ~x[
        <iq type='set'
            id='1'
            from='user-id@localhost/res'
            to='component.localhost'>
          <query xmlns='urn:xmpp:ping'/>
        </iq>
      ]

      assert_stanza_receive ~x[
        <iq type='error'
            id='1'
            from='component.localhost'
            to='user-id@localhost/res'>
          <query xmlns='urn:xmpp:ping'/>
          <error type='cancel'>
            <feature-not-implemented xmlns='urn:ietf:params:xml:ns:xmpp-stazas'/>
          </error>
        </iq>
      ]
  end
end

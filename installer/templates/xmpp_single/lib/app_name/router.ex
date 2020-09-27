defmodule <%= app_module %>.Router do
  use Exampple.Router

  iq "urn:xmpp" do
    get "ping", <%= app_module %>.Xmpp.PingController, :ping
  end

  fallback <%= app_module %>.Xmpp.ErrorController, :error
end

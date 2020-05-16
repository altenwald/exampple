defmodule TestingRouter do
  use Exampple.Router

  iq "urn:exampple:test:" do
    get("get:0", TestingController, :get)
  end
end

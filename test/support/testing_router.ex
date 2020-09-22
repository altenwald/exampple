defmodule TestingRouter do
  use Exampple.Router

  iq "urn:exampple:test" do
    join_with ":"
    get("get:0", TestingController, :get)
  end
end

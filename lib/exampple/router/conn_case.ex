defmodule Exampple.Router.ConnCase do
  @moduledoc """
  ConnCase is used for tests. When a test is using this module
  we have available the start of the Exampple behaviours,
  DummyTcpComponent server and the different asserts.
  """
  defmacro __using__(opts) do
    case opts do
      :client ->
        quote do
          use ExUnit.Case
          import Exampple.Router.ConnCase.Client

          setup do
            start_tcp()
          end
        end

      _ ->
        quote do
          use ExUnit.Case
          import Exampple.Router.ConnCase.Component

          setup do
            start_tcp()
          end
        end
    end
  end
end

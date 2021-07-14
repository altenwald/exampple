defmodule Exampple.Client.CheckException do
  @moduledoc """
  This exception is triggered when a check is not satisfied. Usually
  we could add our own message inside. If we are not adding it, it is
  filled with a predefined text.
  """

  defexception message: "check not safisfied!"
end

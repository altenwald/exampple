defmodule Exampple.Xml.Stream do
  @moduledoc """
  Process a stream chunk by chunk to obtain a XML document.
  """

  alias Saxy.Partial

  @handler Exampple.Xml.Parser.Sender

  def new(pid \\ self()) do
    {:ok, partial} = Partial.new(@handler, pid)
    partial
  end

  def parse(partial, chunk) do
    case Partial.parse(partial, chunk) do
      {:cont, partial} -> partial
      error -> error
    end
  rescue FunctionClauseError ->
    case Partial.parse(partial, "<stream:stream>" <> chunk) do
      {:cont, partial} -> partial
      error -> error
    end
  end

  def terminate(partial) do
    {:ok, _state} = Partial.terminate(partial)
    :ok
  end
end

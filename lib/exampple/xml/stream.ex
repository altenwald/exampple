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

  def parse({:cont, partial}, chunk), do: parse(partial, chunk)

  def parse({:halt, state, rest}, chunk) do
    {:halt, state, rest <> chunk}
  end

  def parse(partial, chunk) do
    Partial.parse(partial, chunk)
  end

  def terminate({:cont, partial}), do: terminate(partial)

  def terminate({:halt, _state, rest}) do
    {:ok, rest}
  end

  def terminate(partial) do
    {:ok, _state} = Partial.terminate(partial)
    {:ok, ""}
  end
end

defmodule Exampple.Tcp do
  @moduledoc """
  TCP client which is in use to abstract all of the connectivity
  aspects for TCP.
  """

  @doc """
  starts a connection to a host and port passed as parameters. The
  handling process is which start the connection in active way.
  """
  def start(host, port) when is_binary(host) and is_integer(port) do
    ## TODO: check if it's better to use instead :once for :active
    host = String.to_charlist(host)
    :gen_tcp.connect(host, port, [:binary, active: true], 1_000)
  end

  @doc """
  Send data. The argments are being positioned to use data in a
  pipeline way.
  """
  def send(data, socket) do
    :gen_tcp.send(socket, data)
    data
  end

  @doc """
  Stops the client connection.
  """
  def stop(socket) do
    :gen_tcp.close(socket)
  end
end

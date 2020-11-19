defmodule Exampple.Tls do
  @moduledoc """
  TLS client which is in use to abstract all of the connectivity
  aspects for TLS.
  """

  @doc """
  upgrades a connection to TLS from TCP.
  """
  def start(socket) do
    :ssl.connect(socket, [:binary, active: true], 1_000)
  end

  @doc """
  starts a connection to a `host` and `port` passed as parameters. The
  handling process is which start the connection in active way and
  using a TLS connection from the very beginning.
  """
  def start(host, port) when is_binary(host) and is_integer(port) do
    ## TODO: check if it's better to use instead :once for :active
    host = String.to_charlist(host)
    :ssl.connect(host, port, [:binary, active: true], 1_000)
  end

  @doc """
  Send `data` via `socket`. The argments are being positioned to use data in a
  pipeline way.
  """
  def send(data, socket) do
    :ssl.send(socket, data)
    data
  end

  @doc """
  Stops the connection passing the `socket` as parameter.
  """
  def stop(socket) do
    :ssl.close(socket)
  end
end

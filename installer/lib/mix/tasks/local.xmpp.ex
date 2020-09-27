defmodule Mix.Tasks.Local.Xmpp do
  use Mix.Task

  @shortdoc "Updates the Exampple project generator locally"

  @moduledoc """
  Updates the Exampple project generator locally.

      mix local.xmpp

  Accepts the same command line options as `archive.install hex xmpp_new`.
  """
  def run(args) do
    Mix.Task.run("archive.install", ["hex", "xmpp_new" | args])
  end
end

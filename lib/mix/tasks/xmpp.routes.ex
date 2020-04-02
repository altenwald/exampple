defmodule Mix.Tasks.Xmpp.Routes do
  use Mix.Task

  @shortdoc "Prints all routes"

  @moduledoc """
  Prints all routes for the router.

      $ mix xmpp.routes

  The default router is inflected from the application
  name.
  """

  @doc false
  def run(args) do
    Mix.Task.run("compile", args)

    router =
      Mix.Project.config()
      |> Keyword.fetch!(:app)
      |> Application.get_env(:router)

    if router do
      IO.inspect(router.route_info())
    else
      IO.puts("No router configured!")
    end
  end
end

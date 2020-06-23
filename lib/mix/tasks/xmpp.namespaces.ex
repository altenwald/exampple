defmodule Mix.Tasks.Xmpp.Namespaces do
  use Mix.Task

  @shortdoc "Prints all namespaces"

  @moduledoc """
  Prints all namespaces for the router.

      $ mix xmpp.namespaces

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
      IO.inspect(router.route_info(:namespaces))
    else
      IO.puts("No router configured!")
    end
  end
end

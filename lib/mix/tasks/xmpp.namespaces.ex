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
      for namespace <- router.route_info(:namespaces), do: pretty_print(namespace)
    else
      IO.puts("No router configured!")
    end
  end

  defp pretty_print(namespace) do
    IO.puts(namespace)
  end
end

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
      routes = router.route_info(:paths)
      sizes = calc_sizes(routes, {0, 0, 0, 0, 0})
      for route <- routes, do: pretty_print(sizes, route)
    else
      IO.puts("No router configured!")
    end
  end

  defp calc_sizes([], sizes), do: sizes

  defp calc_sizes(
         [{stanza_type, type, xmlns, controller, function} | routes],
         {stanza_type_size, type_size, xmlns_size, controller_size, function_size}
       ) do
    stanza_type = to_string(stanza_type)
    type = to_string(type)
    "Elixir." <> controller = to_string(controller)
    function = to_string(function)

    stanza_type_size = max(stanza_type_size, String.length(stanza_type))
    type_size = max(type_size, String.length(type))
    xmlns_size = max(xmlns_size, String.length(xmlns))
    controller_size = max(controller_size, String.length(controller))
    function_size = max(function_size, String.length(function))
    calc_sizes(routes, {stanza_type_size, type_size, xmlns_size, controller_size, function_size})
  end

  defp pretty_print(
         {stanza_type_size, type_size, xmlns_size, controller_size, function_size},
         {stanza_type, type, xmlns, controller, function}
       ) do
    stanza_type = to_string(stanza_type)
    type = to_string(type)
    "Elixir." <> controller = to_string(controller)
    function = to_string(function)

    IO.puts([
      IO.ANSI.blue(),
      String.pad_trailing(stanza_type, stanza_type_size + 1),
      IO.ANSI.yellow(),
      String.pad_trailing(type, type_size + 1),
      IO.ANSI.green(),
      String.pad_trailing(xmlns, xmlns_size + 1),
      IO.ANSI.white(),
      String.pad_trailing(controller, controller_size + 1),
      IO.ANSI.red(),
      String.pad_trailing(function, function_size),
      IO.ANSI.reset()
    ])
  end
end

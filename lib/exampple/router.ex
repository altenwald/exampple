defmodule Exampple.Router do
  require Logger

  alias Exampple.Xml.Xmlel
  alias Exampple.Xmpp.Jid

  defmodule Conn do
    @moduledoc false
    defstruct domain: nil,
              from_jid: nil,
              to_jid: nil,
              id: nil,
              type: nil,
              xmlns: nil,
              stanza_type: nil,
              stanza: nil,
              response: nil

    @type t() :: %__MODULE__{}
  end

  def build_conn(%Xmlel{} = xmlel, domain \\ nil) do
    xmlns =
      case xmlel.children do
        [%Xmlel{} = subel | _] -> Xmlel.get_attr(subel, "xmlns")
        _ -> nil
      end

    %Conn{
      domain: domain,
      from_jid: Jid.parse(Xmlel.get_attr(xmlel, "from")),
      to_jid: Jid.parse(Xmlel.get_attr(xmlel, "to")),
      id: Xmlel.get_attr(xmlel, "id"),
      type: Xmlel.get_attr(xmlel, "type", "normal"),
      xmlns: xmlns,
      stanza_type: xmlel.name,
      stanza: xmlel
    }
  end

  def route(xmlel, domain, otp_app) do
    Logger.debug("[router] processing: #{inspect(xmlel)}")
    # TODO: add this task under a DynamicSupervisor
    Task.start(fn ->
      module = Application.get_env(otp_app, :router)
      conn = build_conn(xmlel, domain)
      query = xmlel.children
      apply(module, :route, [conn, query])
    end)
  end

  defmacro __using__(_opts) do
    quote do
      import Exampple.Router
      Module.register_attribute(__MODULE__, :routes, accumulate: true)
      @before_compile Exampple.Router
    end
  end

  defmacro __before_compile__(env) do
    routes = Module.get_attribute(env.module, :routes)

    route_functions =
      for route <- routes do
        {{stanza_type, type, xmlns, controller, function}, []} = Code.eval_quoted(route)

        quote do
          def route(
                %Exampple.Router.Conn{
                  stanza_type: unquote(stanza_type),
                  xmlns: unquote(xmlns),
                  type: unquote(type)
                } = conn,
                stanza
              ) do
            unquote(controller).unquote(function)(conn, stanza)
          end
        end
      end

    route_info_function =
      quote do
        def route_info(), do: unquote(routes)
      end

    fallback =
      if fback = Module.get_attribute(env.module, :fallback) do
        {{controller, function}, []} = Code.eval_quoted(fback)

        [
          quote do
            def route(conn, stanza), do: unquote(controller).unquote(function)(conn, stanza)
          end
        ]
      else
        []
      end

    [route_info_function | route_functions] ++ [fallback]
  end

  defmacro iq(xmlns_partial \\ "", do: block) do
    quote location: :keep do
      Module.put_attribute(__MODULE__, :stanza_type, "iq")
      Module.put_attribute(__MODULE__, :xmlns_partial, unquote(xmlns_partial))
      unquote(block)
    end
  end

  defmacro message(do: block) do
    quote location: :keep do
      Module.put_attribute(__MODULE__, :stanza_type, "message")
      Module.put_attribute(__MODULE__, :xmlns_partial, "")
      unquote(block)
    end
  end

  defmacro presence(do: block) do
    quote location: :keep do
      Module.put_attribute(__MODULE__, :stanza_type, "presence")
      Module.put_attribute(__MODULE__, :xmlns_partial, "")
      unquote(block)
    end
  end

  def validate_controller!(controller) do
    {module, []} = Code.eval_quoted(controller)

    try do
      module.module_info()
    rescue
      UndefinedFunctionError ->
        module_name =
          module
          |> Module.split()
          |> Enum.join(".")

        raise ArgumentError, """
        The module #{module_name} was not found to create the route,
        use absolute paths or aliases to be sure all of the modules
        are reachable.
        """
    end
  end

  def validate_function!(controller, function) do
    {module, []} = Code.eval_quoted(controller)
    {function, []} = Code.eval_quoted(function)

    unless function_exported?(module, function, 2) do
      module_name =
        module
        |> Module.split()
        |> Enum.join(".")

      raise ArgumentError, """
      The function #{module_name}.#{function}/2 was not found to create
      the route, check the function exists and have 2 parameters to
      receive "conn" and "stanza".
      """
    end
  end

  defmacro get(xmlns, controller, function) do
    validate_controller!(controller)
    validate_function!(controller, function)

    quote location: :keep do
      Module.put_attribute(
        __MODULE__,
        :routes,
        Macro.escape(
          {@stanza_type, "get", @xmlns_partial <> unquote(xmlns), unquote(controller),
           unquote(function)}
        )
      )
    end
  end

  defmacro set(xmlns, controller, function) do
    validate_controller!(controller)
    validate_function!(controller, function)

    quote location: :keep do
      Module.put_attribute(
        __MODULE__,
        :routes,
        Macro.escape(
          {@stanza_type, "set", @xmlns_partial <> unquote(xmlns), unquote(controller),
           unquote(function)}
        )
      )
    end
  end

  defmacro fallback(controller, function) do
    validate_controller!(controller)
    validate_function!(controller, function)

    quote location: :keep do
      Module.put_attribute(
        __MODULE__,
        :fallback,
        Macro.escape({unquote(controller), unquote(function)})
      )
    end
  end
end

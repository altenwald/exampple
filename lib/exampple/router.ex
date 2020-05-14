defmodule Exampple.Router do
  require Logger

  alias Exampple.Router.Task, as: RouterTask

  def route(xmlel, domain, otp_app) do
    Logger.debug("[router] processing: #{inspect(xmlel)}")
    RouterTask.start(xmlel, domain, otp_app)
  end

  defmacro __using__(_opts) do
    quote do
      import Exampple.Router
      Module.register_attribute(__MODULE__, :routes, accumulate: true)
      @envelopes []
      @before_compile Exampple.Router
    end
  end

  defmacro __before_compile__(env) do
    routes = Module.get_attribute(env.module, :routes)
    envelopes = Module.get_attribute(env.module, :envelopes)

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

    envelope_functions =
      for envelope_xmlns <- envelopes do
        quote do
          def route(
                %Exampple.Router.Conn{
                  xmlns: unquote(envelope_xmlns),
                } = conn,
                stanza
              ) do
            {conn, stanza} = Exampple.Xmpp.Envelope.handle(conn, stanza)
            route(conn, stanza)
          end
        end
      end

    [route_info_function | envelope_functions] ++ route_functions ++ [fallback]
  end

  defmacro envelope(xmlns) do
    xmlns_list = if is_list(xmlns), do: xmlns, else: [xmlns]
    quote location: :keep do
      Module.put_attribute(
        __MODULE__,
        :envelopes,
        unquote(xmlns_list)
      )
    end
  end

  defmacro iq(xmlns_partial \\ "", do: block) do
    quote location: :keep do
      Module.put_attribute(__MODULE__, :stanza_type, "iq")
      Module.put_attribute(__MODULE__, :xmlns_partial, unquote(xmlns_partial))
      unquote(block)
    end
  end

  defmacro message(xmlns_partial \\ "", do: block) do
    quote location: :keep do
      Module.put_attribute(__MODULE__, :stanza_type, "message")
      Module.put_attribute(__MODULE__, :xmlns_partial, unquote(xmlns_partial))
      unquote(block)
    end
  end

  defmacro presence(xmlns_partial \\ "", do: block) do
    quote location: :keep do
      Module.put_attribute(__MODULE__, :stanza_type, "presence")
      Module.put_attribute(__MODULE__, :xmlns_partial, unquote(xmlns_partial))
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
        \nThe module #{module_name} was not found to create the route,
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
      \nThe function #{module_name}.#{function}/2 was not found to create
      the route, check the function exists and have 2 parameters to
      receive "conn" and "stanza".
      """
    end
  end

  defmacro error(xmlns \\ "", controller, function) do
    validate_controller!(controller)
    validate_function!(controller, function)

    quote location: :keep do
      Module.put_attribute(
        __MODULE__,
        :routes,
        Macro.escape(
          {@stanza_type, "error", @xmlns_partial <> unquote(xmlns), unquote(controller),
           unquote(function)}
        )
      )
    end
  end

  defmacro unavailable(xmlns \\ "", controller, function) do
    validate_controller!(controller)
    validate_function!(controller, function)

    quote location: :keep do
      Module.put_attribute(
        __MODULE__,
        :routes,
        Macro.escape(
          {@stanza_type, "unavailable", @xmlns_partial <> unquote(xmlns), unquote(controller),
           unquote(function)}
        )
      )
    end
  end

  defmacro subscribe(xmlns \\ "", controller, function) do
    validate_controller!(controller)
    validate_function!(controller, function)

    quote location: :keep do
      Module.put_attribute(
        __MODULE__,
        :routes,
        Macro.escape(
          {@stanza_type, "subscribe", @xmlns_partial <> unquote(xmlns), unquote(controller),
           unquote(function)}
        )
      )
    end
  end

  defmacro subscribed(xmlns \\ "", controller, function) do
    validate_controller!(controller)
    validate_function!(controller, function)

    quote location: :keep do
      Module.put_attribute(
        __MODULE__,
        :routes,
        Macro.escape(
          {@stanza_type, "subscribed", @xmlns_partial <> unquote(xmlns), unquote(controller),
           unquote(function)}
        )
      )
    end
  end

  defmacro unsubscribe(xmlns \\ "", controller, function) do
    validate_controller!(controller)
    validate_function!(controller, function)

    quote location: :keep do
      Module.put_attribute(
        __MODULE__,
        :routes,
        Macro.escape(
          {@stanza_type, "unsubscribe", @xmlns_partial <> unquote(xmlns), unquote(controller),
           unquote(function)}
        )
      )
    end
  end

  defmacro unsubscribed(xmlns \\ "", controller, function) do
    validate_controller!(controller)
    validate_function!(controller, function)

    quote location: :keep do
      Module.put_attribute(
        __MODULE__,
        :routes,
        Macro.escape(
          {@stanza_type, "unsubscribed", @xmlns_partial <> unquote(xmlns), unquote(controller),
           unquote(function)}
        )
      )
    end
  end

  defmacro probe(xmlns \\ "", controller, function) do
    validate_controller!(controller)
    validate_function!(controller, function)

    quote location: :keep do
      Module.put_attribute(
        __MODULE__,
        :routes,
        Macro.escape(
          {@stanza_type, "probe", @xmlns_partial <> unquote(xmlns), unquote(controller),
           unquote(function)}
        )
      )
    end
  end

  defmacro normal(xmlns \\ "", controller, function) do
    validate_controller!(controller)
    validate_function!(controller, function)

    quote location: :keep do
      Module.put_attribute(
        __MODULE__,
        :routes,
        Macro.escape(
          {@stanza_type, "normal", @xmlns_partial <> unquote(xmlns), unquote(controller),
           unquote(function)}
        )
      )
    end
  end

  defmacro headline(xmlns \\ "", controller, function) do
    validate_controller!(controller)
    validate_function!(controller, function)

    quote location: :keep do
      Module.put_attribute(
        __MODULE__,
        :routes,
        Macro.escape(
          {@stanza_type, "headline", @xmlns_partial <> unquote(xmlns), unquote(controller),
           unquote(function)}
        )
      )
    end
  end

  defmacro groupchat(xmlns \\ "", controller, function) do
    validate_controller!(controller)
    validate_function!(controller, function)

    quote location: :keep do
      Module.put_attribute(
        __MODULE__,
        :routes,
        Macro.escape(
          {@stanza_type, "groupchat", @xmlns_partial <> unquote(xmlns), unquote(controller),
           unquote(function)}
        )
      )
    end
  end

  defmacro chat(xmlns \\ "", controller, function) do
    validate_controller!(controller)
    validate_function!(controller, function)

    quote location: :keep do
      Module.put_attribute(
        __MODULE__,
        :routes,
        Macro.escape(
          {@stanza_type, "chat", @xmlns_partial <> unquote(xmlns), unquote(controller),
           unquote(function)}
        )
      )
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

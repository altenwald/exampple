defmodule Exampple.Router do
  require Logger

  alias Exampple.Xml.Xmlel

  @dynsup Exampple.Router.Task.Monitor.Supervisor
  @monitor Exampple.Router.Task.Monitor
  @default_timeout 5_000

  def route(xmlel, domain, otp_app, timeout \\ @default_timeout) do
    Logger.debug("[router] processing: #{inspect(xmlel)}")
    DynamicSupervisor.start_child(@dynsup, {@monitor, [xmlel, domain, otp_app, timeout]})
  end

  defmacro __using__(_opts) do
    quote do
      import Exampple.Router
      Module.register_attribute(__MODULE__, :routes, accumulate: true)
      Module.register_attribute(__MODULE__, :namespaces, accumulate: true)
      Module.register_attribute(__MODULE__, :identities, accumulate: true)
      Module.register_attribute(__MODULE__, :includes, accumulate: true)
      Module.register_attribute(__MODULE__, :features, accumulate: true)
      @envelopes []
      @namespace_separator ":"
      @before_compile Exampple.Router
    end
  end

  defmacro __before_compile__(env) do
    envelopes = Module.get_attribute(env.module, :envelopes)
    disco = Module.get_attribute(env.module, :disco, false)
    includes = Module.get_attribute(env.module, :includes, [])

    routes =
      for route <- Module.get_attribute(env.module, :routes) do
        {route, _} = Code.eval_quoted(route)
        route
      end

    inc_routes =
      for module <- includes do
        Code.ensure_compiled(module)

        for route <- module.route_info(:paths) do
          {module, route}
        end
      end
      |> List.flatten()

    route_functions =
      for {stanza_type, type, xmlns, controller, function} <- routes do
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

    inc_route_functions =
      for {route, {stanza_type, type, xmlns, _, _}} <- inc_routes do
        quote do
          def route(
                %Exampple.Router.Conn{
                  stanza_type: unquote(stanza_type),
                  xmlns: unquote(xmlns),
                  type: unquote(type)
                } = conn,
                stanza
              ) do
            unquote(route).route(conn, stanza)
          end
        end
      end

    all_routes = routes ++ for {_, route} <- inc_routes, do: route

    fallback =
      if fback = Module.get_attribute(env.module, :fallback) do
        {controller, function} = fback
        {controller, []} = Code.eval_quoted(controller)

        [
          quote do
            def route(conn, stanza) do
              unquote(controller).unquote(function)(conn, stanza)
            end
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
                  xmlns: unquote(envelope_xmlns)
                } = conn,
                stanza
              ) do
            case Exampple.Xmpp.Envelope.handle(conn, stanza) do
              {conn, stanza} -> route(conn, stanza)
              nil -> :ok
            end
          end
        end
      end

    namespaces =
      env.module
      |> Module.get_attribute(:namespaces)
      |> Enum.reject(& &1 == "")

    namespaces =
      (namespaces ++ Module.get_attribute(env.module, :features, []))
      |> Enum.uniq()
      |> Enum.sort()

    inc_namespaces =
      for module <- includes do
        module.route_info(:namespaces)
      end
      |> List.flatten()

    disco_info =
      if disco do
        namespaces =
          for namespace <- namespaces ++ inc_namespaces do
            Macro.escape(Xmlel.new("feature", %{"var" => namespace}))
          end

        identity =
          for {_, _, [category, type, name]} <- Module.get_attribute(env.module, :identities) do
            Macro.escape(
              Xmlel.new("identity", %{
                "category" => category,
                "type" => type,
                "name" => name
              })
            )
          end

        identity ++ namespaces
      else
        []
      end

    discovery =
      quote do
        def route(
              %Exampple.Router.Conn{
                to_jid: %Exampple.Xmpp.Jid{node: "", resource: ""},
                xmlns: "http://jabber.org/protocol/disco#info"
              } = conn,
              [stanza]
            ) do
          payload = %Xmlel{stanza | children: unquote(disco_info)}

          conn
          |> Exampple.Xmpp.Stanza.iq_resp([payload])
          |> Exampple.Component.send()
        end
      end

    route_info_function =
      quote do
        def route_info(:paths), do: unquote(Macro.escape(all_routes))
        def route_info(:namespaces), do: unquote(namespaces)
      end

    [route_info_function | envelope_functions] ++
      [discovery] ++
      inc_route_functions ++
      route_functions ++
      [fallback]
  end

  defmacro join_with(separator) when is_binary(separator) do
    quote do
      @namespace_separator unquote(separator)
    end
  end

  defmacro join_with(other) do
    raise """
    join_with only accepts String as parameter #{inspect(other)} is
    not permitted. Default is ":".
    """
  end

  defmacro includes(module) do
    quote do
      @includes unquote(module)
    end
  end

  defmacro envelope(xmlns) do
    xmlns_list = if is_list(xmlns), do: xmlns, else: [xmlns]

    quote location: :keep do
      xmlns_list = unquote(xmlns_list)
      Module.put_attribute(__MODULE__, :envelopes, xmlns_list)

      for xmlns <- xmlns_list do
        Module.put_attribute(__MODULE__, :namespaces, xmlns)
      end
    end
  end

  defmacro iq(xmlns_partial \\ "", do: block) do
    quote location: :keep do
      Module.put_attribute(__MODULE__, :stanza_type, "iq")
      Module.put_attribute(__MODULE__, :xmlns_partial, unquote(xmlns_partial))
      @namespace_separator ":"
      unquote(block)
    end
  end

  defmacro message(xmlns_partial \\ "", do: block) do
    quote location: :keep do
      Module.put_attribute(__MODULE__, :stanza_type, "message")
      Module.put_attribute(__MODULE__, :xmlns_partial, unquote(xmlns_partial))
      @namespace_separator ":"
      unquote(block)
    end
  end

  defmacro presence(xmlns_partial \\ "", do: block) do
    quote location: :keep do
      Module.put_attribute(__MODULE__, :stanza_type, "presence")
      Module.put_attribute(__MODULE__, :xmlns_partial, unquote(xmlns_partial))
      @namespace_separator ":"
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

  defmacro discovery(block \\ nil) do
    if block do
      quote do
        Module.put_attribute(__MODULE__, :disco, true)
        unquote(block)
      end
    else
      quote do
        Module.put_attribute(__MODULE__, :disco, true)
      end
    end
  end

  defmacro identity(opts) do
    quote do
      opts = unquote(opts)

      unless Module.get_attribute(__MODULE__, :disco, false) do
        raise """
        identity MUST be inside of a discovery block.
        """
      end

      unless category = opts[:category] do
        raise """
        identity MUST contain a category option.
        """
      end

      unless type = opts[:type] do
        raise """
        identity MUST contain a type option.
        """
      end

      unless name = opts[:name] do
        raise """
        identity MUST contain a name option.
        """
      end

      Module.put_attribute(__MODULE__, :identities, Macro.escape({category, type, name}))
    end
  end

  defmacro feature(namespace) do
    quote do
      @features unquote(namespace)
    end
  end

  def ns_join([], _separator), do: ""
  def ns_join(["" | chunks], separator), do: ns_join(chunks, separator)

  def ns_join(chunks, separator) do
    chunks
    |> Enum.map(&String.trim(&1, separator))
    |> Enum.join(separator)
  end

  defmacro error(xmlns \\ "", controller, function) do
    validate_controller!(controller)
    validate_function!(controller, function)

    quote location: :keep do
      namespace = Exampple.Router.ns_join([@xmlns_partial, unquote(xmlns)], @namespace_separator)

      Module.put_attribute(
        __MODULE__,
        :routes,
        Macro.escape({@stanza_type, "error", namespace, unquote(controller), unquote(function)})
      )

      Module.put_attribute(__MODULE__, :namespaces, namespace)
    end
  end

  defmacro unavailable(xmlns \\ "", controller, function) do
    validate_controller!(controller)
    validate_function!(controller, function)

    quote location: :keep do
      namespace = Exampple.Router.ns_join([@xmlns_partial, unquote(xmlns)], @namespace_separator)

      Module.put_attribute(
        __MODULE__,
        :routes,
        Macro.escape(
          {@stanza_type, "unavailable", namespace, unquote(controller), unquote(function)}
        )
      )

      Module.put_attribute(__MODULE__, :namespaces, namespace)
    end
  end

  defmacro subscribe(xmlns \\ "", controller, function) do
    validate_controller!(controller)
    validate_function!(controller, function)

    quote location: :keep do
      namespace = Exampple.Router.ns_join([@xmlns_partial, unquote(xmlns)], @namespace_separator)

      Module.put_attribute(
        __MODULE__,
        :routes,
        Macro.escape(
          {@stanza_type, "subscribe", namespace, unquote(controller), unquote(function)}
        )
      )

      Module.put_attribute(__MODULE__, :namespaces, namespace)
    end
  end

  defmacro subscribed(xmlns \\ "", controller, function) do
    validate_controller!(controller)
    validate_function!(controller, function)

    quote location: :keep do
      namespace = Exampple.Router.ns_join([@xmlns_partial, unquote(xmlns)], @namespace_separator)

      Module.put_attribute(
        __MODULE__,
        :routes,
        Macro.escape(
          {@stanza_type, "subscribed", namespace, unquote(controller), unquote(function)}
        )
      )

      Module.put_attribute(__MODULE__, :namespaces, namespace)
    end
  end

  defmacro unsubscribe(xmlns \\ "", controller, function) do
    validate_controller!(controller)
    validate_function!(controller, function)

    quote location: :keep do
      namespace = Exampple.Router.ns_join([@xmlns_partial, unquote(xmlns)], @namespace_separator)

      Module.put_attribute(
        __MODULE__,
        :routes,
        Macro.escape(
          {@stanza_type, "unsubscribe", namespace, unquote(controller), unquote(function)}
        )
      )

      Module.put_attribute(__MODULE__, :namespaces, namespace)
    end
  end

  defmacro unsubscribed(xmlns \\ "", controller, function) do
    validate_controller!(controller)
    validate_function!(controller, function)

    quote location: :keep do
      namespace = Exampple.Router.ns_join([@xmlns_partial, unquote(xmlns)], @namespace_separator)

      Module.put_attribute(
        __MODULE__,
        :routes,
        Macro.escape(
          {@stanza_type, "unsubscribed", namespace, unquote(controller), unquote(function)}
        )
      )

      Module.put_attribute(__MODULE__, :namespaces, namespace)
    end
  end

  defmacro probe(xmlns \\ "", controller, function) do
    validate_controller!(controller)
    validate_function!(controller, function)

    quote location: :keep do
      namespace = Exampple.Router.ns_join([@xmlns_partial, unquote(xmlns)], @namespace_separator)

      Module.put_attribute(
        __MODULE__,
        :routes,
        Macro.escape({@stanza_type, "probe", namespace, unquote(controller), unquote(function)})
      )

      Module.put_attribute(__MODULE__, :namespaces, namespace)
    end
  end

  defmacro normal(xmlns \\ "", controller, function) do
    validate_controller!(controller)
    validate_function!(controller, function)

    quote location: :keep do
      namespace = Exampple.Router.ns_join([@xmlns_partial, unquote(xmlns)], @namespace_separator)

      Module.put_attribute(
        __MODULE__,
        :routes,
        Macro.escape({@stanza_type, "normal", namespace, unquote(controller), unquote(function)})
      )

      Module.put_attribute(__MODULE__, :namespaces, namespace)
    end
  end

  defmacro headline(xmlns \\ "", controller, function) do
    validate_controller!(controller)
    validate_function!(controller, function)

    quote location: :keep do
      namespace = Exampple.Router.ns_join([@xmlns_partial, unquote(xmlns)], @namespace_separator)

      Module.put_attribute(
        __MODULE__,
        :routes,
        Macro.escape(
          {@stanza_type, "headline", namespace, unquote(controller), unquote(function)}
        )
      )

      Module.put_attribute(__MODULE__, :namespaces, namespace)
    end
  end

  defmacro groupchat(xmlns \\ "", controller, function) do
    validate_controller!(controller)
    validate_function!(controller, function)

    quote location: :keep do
      namespace = Exampple.Router.ns_join([@xmlns_partial, unquote(xmlns)], @namespace_separator)

      Module.put_attribute(
        __MODULE__,
        :routes,
        Macro.escape(
          {@stanza_type, "groupchat", namespace, unquote(controller), unquote(function)}
        )
      )

      Module.put_attribute(__MODULE__, :namespaces, namespace)
    end
  end

  defmacro chat(xmlns \\ "", controller, function) do
    validate_controller!(controller)
    validate_function!(controller, function)

    quote location: :keep do
      namespace = Exampple.Router.ns_join([@xmlns_partial, unquote(xmlns)], @namespace_separator)

      Module.put_attribute(
        __MODULE__,
        :routes,
        Macro.escape({@stanza_type, "chat", namespace, unquote(controller), unquote(function)})
      )

      Module.put_attribute(__MODULE__, :namespaces, namespace)
    end
  end

  defmacro get(xmlns, controller, function) do
    validate_controller!(controller)
    validate_function!(controller, function)

    quote location: :keep do
      namespace = Exampple.Router.ns_join([@xmlns_partial, unquote(xmlns)], @namespace_separator)

      Module.put_attribute(
        __MODULE__,
        :routes,
        Macro.escape({@stanza_type, "get", namespace, unquote(controller), unquote(function)})
      )

      Module.put_attribute(__MODULE__, :namespaces, namespace)
    end
  end

  defmacro set(xmlns, controller, function) do
    validate_controller!(controller)
    validate_function!(controller, function)

    quote location: :keep do
      namespace = Exampple.Router.ns_join([@xmlns_partial, unquote(xmlns)], @namespace_separator)

      Module.put_attribute(
        __MODULE__,
        :routes,
        Macro.escape({@stanza_type, "set", namespace, unquote(controller), unquote(function)})
      )

      Module.put_attribute(__MODULE__, :namespaces, namespace)
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

# Exampple

eXaMPPle is a XMPP framework to build components using a router, controllers
and an easy way to generate stanzas.

## Installation

You can install the application for your project in the following way:

```elixir
def deps do
  [
    {:exampple, github: "altenwald/exampple"}
  ]
end
```

## Getting started

To use Exampple you only need to add the following information for the `config/config.exs` file:

```elixir
config :myapp,
  router: Myapp.Router

config :myapp, Exampple.Component,
  domain: "mycomponent.example.com",
  host: "localhost",
  password: "guest",
  ping: 30_000,
  port: 5252,
  set_from: true,
  trimmed: true,
  auto_connect: true
```

The configuration for you XMPP Server should accept the connection for a component in the port 5252, for the domain `mycomponent.example.com` (so, it's suppose your XMPP server is handling the `example.com` domain), both installed in the same machine.

After that, is a good idea to have inside of the supervisor the example server, usually it should be in your `lib/myapp/application.ex` file:

```elixir
children = [
  {Exampple.Component, [otp_app: :myapp]}
]
```

And a new module should be created, as mention the first part of the configuration, to define the router, in this example, something like `lib/myapp/router.ex`:

```
defmodule Myapp.Router do
  use Exampple.Router

  iq "jabber:iq:" do
    get "roster", Myapp.Xmpp.RosterController, :get
  end

  fallback Myapp.Xmpp.ErrorController, :error
end
```

This is a very small example with only two controllers. The construction tries to match as much as possible with the data provided in the incoming stanza:

- stanza type: iq, presence or message
- namespace: this is split in two putting the base in the container matching the stanza type and the other part with the type. In the above example, we have matching for "jabber:iq:roster".
- type: which is defined in the type attribute of the stanza, for iq: get, set or error.

And that's choosing a module and a function to be called. Which we call a controller.

The last file you need to create is the controller `lib/myapp/xmpp/roster_controller.ex`:

```elixir
defmodule Myapp.Xmpp.RosterController do
  use Exampple.Component

  def get(conn, query) do
    conn
    |> iq_resp(query)
    |> send()
  end
end
```

This way we have a perfect echo. You can process the data coming in `query` and then perform a better output. Also, you can generate an error like the _fallback_ we develop under `lib/myapp/xmpp/error_controller.ex`:

```elixir
defmodule Myapp.Xmpp.ErrorController do
  use Exampple.Component

  def error(conn, _query) do
    conn
    |> iq_error("feature-not-implemented")
    |> send()
  end
end
```

More coming soon!

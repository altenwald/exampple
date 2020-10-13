# Exampple

[![Build Status](https://img.shields.io/travis/altenwald/exampple/master.svg)](https://travis-ci.org/altenwald/exampple)
[![Coverage Status](https://coveralls.io/repos/github/altenwald/exampple/badge.svg)](https://coveralls.io/github/altenwald/exampple)
[![License: LGPL 2.1](https://img.shields.io/github/license/altenwald/exampple.svg)](https://raw.githubusercontent.com/altenwald/exampple/master/COPYING)
[![Hex](https://img.shields.io/hexpm/v/exampple.svg)](https://hex.pm/packages/exampple)
[![Inline docs](http://inch-ci.org/github/altenwald/exampple.png)](http://inch-ci.org/github/altenwald/exampple)

eXaMPPle is a XMPP framework to build components using a router, controllers
and an easy way to generate stanzas. It also has facilities to perform 
functional and system tests.

## Installation

You can install the application for your project in the following way:

```elixir
def deps do
  [
    {:exampple, "~> 0.4.0"}
  ]
end
```

You can also create a new project using [phx_new](https://github.com/altenwald/exampple/blob/master/installer/README.md).

## Elixir and OTP Versions

We recommend to use OTP 22+ and Elixir 1.10+. You can see in the following table the tests are they are made on [Travis CI](https://travis-ci.org/github/altenwald/exampple):

| Erlang | Elixir | Support            |
|:-------|:-------|:-------------------|
| 23.1   | 1.10   | :heavy_check_mark: |
| 23.0   | 1.10   | :heavy_check_mark: |
| 23.0   | 1.9    | :x:                |
| 22.3   | 1.10   | :heavy_check_mark: |
| 22.3   | 1.9    | :heavy_check_mark: |
| 22.2   | 1.10   | :heavy_check_mark: |
| 22.2   | 1.9    | :heavy_check_mark: |
| 22.1   | 1.10   | :heavy_check_mark: |
| 22.1   | 1.9    | :heavy_check_mark: |

## Donation

If you want to support the project to advance faster with the development you can make a donation. Thanks!

[![paypal](https://www.paypalobjects.com/en_US/GB/i/btn/btn_donateCC_LG.gif)](https://paypal.me/altenwaldsolutions)

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

```elixir
defmodule Myapp.Router do
  use Exampple.Router

  iq "jabber:iq" do
    get "roster", Myapp.Xmpp.RosterController, :get
  end

  fallback Myapp.Xmpp.ErrorController, :error
end
```

This is a very small example with only two controllers. The construction tries to match as much as possible with the data provided in the incoming stanza:

- **stanza type**: iq, presence or message
- **namespace**: this is split in two putting the base in the container matching the stanza type and the other part with the type. In the above example, we have matching for "jabber:iq:roster".
- **type**: which is defined in the type attribute of the stanza, for iq: get, set or error.

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

Note that `send/1` is performing the sent of the stanza and it's not based on the return like other frameworks like Phoenix. You can perform as many sent as you need.

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

## Configuration

As we saw above, the configuration is split in two pars, the configuration of the router to be localized by Exampple inside of your project, and the configuration for the connection to the XMPP server.

The router localization is configured with these lines:

```elixir
config :myapp,
  router: Myapp.Router
```

Of course, you have to create the `Myapp.Router` module changing `Myapp` for the real name of your project or the base namespace you are using. We will see how to create the router in the [Router](#router) section.

About the connection, the configuration is as follows:

```elixir
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

The possible configuration entries are:

- `domain` (string): the XMPP domain for the component.
- `host` (string): the XMPP server IP or name to be connected to.
- `password` (string): the secret for the connection to the XMPP server.
- `ping` (false | integer): indicate the number of milliseconds to perform the ping or `false` otherwise. The default value is `false`.
- `port` (integer): the port to be connected with the XMPP Server.
- `set_from` (boolean): indicate if all of the sent stanzas should be modified to have the `from` as is in the `domain` entry. This is useful if the server cannot let us to use another different `from`. Default value is `false`.
- `trimmed` (boolean): when a stanza is received it is parsed. Setting `trimmed` to `true` all of the blank spaces between tags are removed. If you want to keep the stanza as it was set this value to `false` but keep in mind it could be a bit difficult to match. Default value is `false`.
- `auto_connect` (boolean | integer): when the component process is created y configured it should to perform the connection to the XMPP Server. We have three different options with `auto_connect`. If we choose `true`, the server is auto-connected. If we choose `false` it is not. When we choose a number of milliseconds then it is not connected immediately, it is awaiting that amount of time. Default is `false`.
- `router_handler` (module): let us to configure the module we want to use to handel the routes. Useful for tests.
- `tcp_handler` (module): let us to configure the module we want to use to handle the TCP connection. Useful for tests.

## Choose your XMPP Server

Note that you only need a server which is supporting the [XEP-0114](https://xmpp.org/extensions/xep-0114.html). At the moment we can see there is available these servers:

- [ejabberd](https://www.ejabberd.im/): the most popular thanks to Whatsapp.
- [MongooseIM](https://mongooseim.readthedocs.io/en/latest/): the fork from ejabberd made by Erlang Solutions.
- [OpenFire](https://www.igniterealtime.org/projects/openfire/): a Java server with a lot of plugins.
- [Prosody](https://prosody.im/doc/xmpp): a Lua server with great XMPP support and very easy to extend.
- [Tigase](https://tigase.net/xmpp-server): a Java server prepared for scalability.

The configuration for the server depends on each one, you can go to their respective websites and search the configuration for the components module.

## Mix tasks

When you are creating a project using Exampple you will have available two new commands for mix:

- `mix xmpp.routes`: shows a list of all of the routes available (with colors):

```
$ mix xmpp.routes
iq get urn:xmpp:ping  Myapp.Xmpp.PingController      ping
iq get urn:xmpp:mam:2 Myapp.Xmpp.ArchivingController get
```

- `mix xmpp.namespaces`: shows a list of namespaces (similar to the previous one but not using colors and only showing the namespaces):

```
$ mix xmpp.namespaces
urn:xmpp:ping
urn:xmpp:mam:2
```

## Routing

The router was created inspired by the router from Phoenix Framework. The router let us configure how the system handles the stanzas. Based on different matches:

- Stanza type: iq, presence or message.
- Namespace.
- Type: depending on the stanza type this _type_ could be chat, groupchat, headline, normal, error, set, get, result, ...

With these we can route the stanzas to a specific module and function: the **controllers**. For example, if we have this routing file:

```elixir
defmodule Myapp.Router do
  use Exampple.Router

  iq "urn:xmpp" do
    get "ping", Myapp.Xmpp.PingController, :ping
    get "mam:2", Myapp.Xmpp.ArchivingController, :get
  end

  iq "http://jabber.org/" do
    join_with "/"
    get "disco#info", Myapp.Xmpp.DiscoController, :info
    get "disco#items", Myapp.Xmpp.DiscoController, :items
  end

  fallback Myapp.Xmpp.ErrorController, :error
end
```

The whole flow is as follows:

```
    +-----------+   +----------+   +----------+   +----------+   +------------+
    |           |   |          |   |          |   |          |   |            |
+-->+ Component +-->+  Router  +-->+   Task   +-->+  CRoute  +-->+ Controller |
    |           |   |          |   |          |   |          |   |            |
    +-----------+   +----------+   +----------+   +----------+   +------------+
```

These elements are:

- `Exampple.Component` is a state machine with a TCP server. It is handling not only the connectivity to the server but also the sent to the packets to the XML parser and when it is received an stanza, it is sent through the next step in the flow.
- `Exampple.Router` is an only one function in charge to call to the `Exampple.Router.Task` supervisor and start a new task to handle the stanza. The task starts running the function implemented in the custom router configured via `otp_app` parameter in the configuration.
- _CRoute_ is the result of the implementation of our own server, as you can see above, we have 2 different handlers for `usr:xmpp:ping` and `urn:xmpp:mam:2`, both using `iq` and `get` types. The function `route/2` tries to match against the configuration offered in the _router_ and if one is matching, we rung the _controller_ and the specified _function_.
- `Controller` is a module which we have to implement using the `Exampple.Component` facilities (`use Exampple.Component`). We will talk about controllers further.

### Matching Routes

In the configuration for the router we can specify different kind of routes. For example:

```elixir
defmodule Myapp.Router do
  use Exampple.Router

  iq "urn:xmpp" do
    get "ping", Myapp.Xmpp.PingController, :ping
  end

  presence do
    available Myapp.Xmpp.PresenceController, :available
    unavailable Myapp.Xmpp.PresenceController, :unavailable
  end

  message do
    normal Myapp.Xmpp.MessageController, :normal
    groupchat Myapp.Xmpp.GroupchatController, :message
  end
end
```

The namespace is defined in two parts, in the stanza type we can set the base (e.g. in the first block defining `"urn:xmpp"`) and in the type sentence, inside of the stanza block where we can see the last part (e.g. in the first block we can see inside `"ping"`). Both parts are merged using the _connector_ which is by default `:`. If we need to change to another connector, like `/`, we can use inside of the stanza block:

```elixir
join_with "/"
```

In addition, the namespace is optional, we can set the base for the namespace in the message, presence or iq main sections and then specify the completion for the namespace inside of the specific type. The way to perform the match is:

```xml
<iq type='get'>
  <query xmlns='urn:xmpp:ping'/>
</iq>
```

This is the minimum message which is going to match with the first entry for the router which we declared above. This is going to parse the stanza to generate an `Exampple.Router.Conn` struct and then using the _query_ in `Exampple.Xml.Xmlel` format the controller we implement as `Myapp.Xmpp.PingController` is going to be called using the function `ping/2`.

### Fallback

When there is no match we can declare a special _fallback_:

```elixir
defmodule Myapp.Router do
  use Exampple.Router

  iq "urn:xmpp:" do
    get "ping", Myapp.Xmpp.PingController, :ping
  end

  fallback Myapp.Xmpp.ErrorController, :error
end
```

This is defining only the module and the function which will be called to handle the unknown stanza.

### Discovery

To let us implement [XEP-0030](https://xmpp.org/extensions/xep-0030.html) in an easy way, we can use the following configuration inside of our router module:

```elixir
defmodule Myapp.Router do
  use Exampple.Router

  discovery()

  iq "urn:xmpp:" do
    get "ping", Myapp.Xmpp.PingController, :ping
  end
end
```

This is including a new namespace (keep in mind this one is not shown using `mix xmpp.routes` or `mix xmpp.namespaces`). You can send to the component:

```xml
<iq type='get'
    from='user@example.com/res'
    to='component.example.com'
    id='info1'>
  <query xmlns='http://jabber.org/protocol/disco#info'/>
</iq>
```

And the response keeping in mind the previous example should be:

```xml
<iq type='result'
    from='component.example.com'
    to='user@example.com/res'
    id='info1'>
  <query xmlns='http://jabber.org/protocol/disco#info'>
    <feature var='urn:xmpp:ping'/>
  </query>
</iq>
```

Inside of the discovery macro we can add also the identity for the component:

```elixir
defmodule Myapp.Router do
  use Exampple.Router

  discovery do
    identity category: "component", type: "generic", name: "myapp"
  end

  iq "urn:xmpp:" do
    get "ping", Myapp.Xmpp.PingController, :ping
  end
end
```

About the information you can configure for identity you can see the [available categories](https://xmpp.org/registrar/disco-categories.html). We are going to list here the categories and inside of the their possible types:

* account
  * admin: for an administrative account.
  * anonymous: for a "guest" account.
  * registered: for a registered or provisioned account (non-administrative).
* auth
  * cert: authenticates based on external certificates.
  * generic: different from other types in this category.
  * ldap: authenticates against an LDAP database.
  * ntlm: authenticates against an NT domain.
  * pam: authenticates against a PAM system.
  * radius: authenticates against a Radius system.
* automation
  * command-list: the node for a list of commands (see [XEP-0050](https://xmpp.org/extensions/xep-0050.html)).
  * command-node: a node for a specific command.
  * rpc: supports Jabber-RPC (see [XEP-0009](https://xmpp.org/extensions/xep-0009.html)).
  * soap: supports SOAP XMPP Binding (see [XEP-0072](https://xmpp.org/extensions/xep-0072.html)).
  * translation: provides automated translation services (see [XEP-0171](https://xmpp.org/extensions/xep-0171.html)).
* client
  * bot: automated client.
  * console: minimal non-gui client used on dumb terminals or text-only screens.
  * game: client running on a game console.
  * handheld: client running on a PDA, RIM device, or other handheld.
  * pc: full-GUI client used on desktops and laptops.
  * phone: client running on a mobile phone or other telephony service.
  * sms: client using SMS.
  * web: client operated from within a web browser.
* collaboration
  * whiteboard: Multi-user whiteboarding service.
* component
  * archive: archives traffic.
  * c2s: handles client connections.
  * generic: other than one of the registered types.
  * load: handles load-balancing.
  * log: logs the server information.
  * presence: provides presence information.
  * router: handles the core routing logic.
  * s2s: handles server connections.
  * sm: manages user sessions.
  * stats: provides server statistics.
* conference
  * irc: Internet Relay Chat service.
  * text: text conferencing service.
* directory
  * chatroom: directory of chatrooms.
  * group: provides shared roster groups.
  * user: directory of end users (JUD).
  * waitinglist: directory of waiting list entries.
* gateway
  * aim: AOL Instant Messenger.
  * facebook
  * gadu-gadu
  * http-ws: provides HTTP Web Services access.
  * icq
  * irc
  * lcs: Microsoft Live Communications Server.
  * mrim: mail.ru IM service.
  * msn: MSN Messenger.
  * myspaceim
  * ocs: Microsoft Office Communications Server.
  * qq
  * sametime: IBM Lotus Sametime
  * simple
  * skype
  * sms
  * smtp
  * tlen
  * xfire: Xfire gaming and IM service.
  * xmpp: gateway to another XMPP service (not s2s).
  * yahoo
* headline
  * newmail: notifies about new email messages.
  * rss: RSS notification service.
  * weather: provides weather alerts.
* hierarchy
  * branch: contains more nodes.
  * leaf: does not contain further nodes.
* proxy
  * bytestreams: SOCKS5 bytestreams proxy service.
* pubsub
  * collection
  * leaf
  * pep: personal eventing service (see [XEP-0163(https://xmpp.org/extensions/xep-0163.html)]).
  * service: pubsub supporting [XEP-0060](https://xmpp.org/extensions/xep-0060.html).
* server
  * im: server for IM and presence.
* store
  * berkeley: stores data in a Berkeley database.
  * file: stores data on the file system.
  * generic: other than one of the registered types.
  * ldap: stores data in a LDAP database.
  * mysql: stores data in a MySQL database.
  * oracle: stores data in a Oracle database.
  * postgres: stores data in a PostgreSQL database.

You can provide as name the name of the component or whatever which could means the mission of the component to be clear for the rest of the clients, server and components.

It is also possible to indicate a feature when they are not being to be attended directly by a request. For example, inside of [XEP-0369](https://xmpp.org/extensions/xep-0355.html) we could use the namespace `urn:xmpp:mix:core:1` but also there's a new to indicate support for `urn:xmpp:mix:core:1#create`. This is not the only one XEP which includes the use of the sharp symbol to give more information about support. To add this, we can use `feature`:

```elixir
defmodule Myapp.Router do
  use Exampple.Router

  discovery do
    identity category: "component", type: "generic", name: "myapp"
  end

  iq "urn:xmpp:mix" do
    get "core:1", Myapp.Xmpp.MixCoreController, :core
  end

  feature "urn:xmpp:mix:core:1#create"
end
```

### Envelope

Because we can configure XMPP to delegate using [XEP-0355](https://xmpp.org/extensions/xep-0355.html), we could configure to receive in a transparent way the incoming messages inside of their envelope and reply them just as if we were inside of the XMPP Server replying directly to the user or component asking.

The configuration is like this:

```elixir
defmodule Myapp.Router do
  use Exampple.Router

  envelope "urn:xmpp:delegation:1"

  iq "urn:xmpp:" do
    get "ping", Myapp.Xmpp.PingController, :ping
  end
end
```

Using this code we say to the router we are going to implement as wrapper the namespaces `urn:xmpp:delegation:1` and the `urn:xmpp:forward:0` implicitly because is in use by the [XEP-0355](https://xmpp.org/extensions/xep-0355.html). Everything regarding the envelope is configured inside of the connection variable passed to the controlled so, every response we perform using that connection will be using the same envelop to send it via the XMPP Server.

### Including other Routers

It is possible to include other routers. This could be made to include other controllers and routes from a dependency or in order to split the router in different applications (umbrella) inside of our project.

This could be performed as:

```elixir
defmodule MyMainApp.Router do
  use Exampple.Router

  includes MySubApp1.Router
  includes MySubApp2.Router
end
```

This way the `MyMainApp.Router` will have the content (routes and namespaces) from the other routes.

Note that the information regarding discovery is copied only for namespaces, the identity, category and other information is not copied and should be defined.

## Controllers

The controllers are the place where we are going to implement all of these functions we indicate during the routing writing process. For example:

```elixir
defmodule Myapp.Router do
  use Exampple.Router

  iq "urn:xmpp" do
    get "ping", Myapp.Xmpp.PingController, :ping
  end
end
```

For this router configuration we have to implement our `Myapp.Xmpp.PingController` module where should appear a function called `ping` accepting two parameters:

- `conn`: this is going to be a transformation of the incoming stanza to get more information from it and letting us to perform more actions easily.
- `query`: the payload included in the main stanza which we could process or perform some kind of pattern matching if we want.

The usual implementation for the ping:

```elixir
defmodule Myapp.Xmpp.PingController do
  use Exampple.Component

  def ping(conn, query) do
    conn
    |> iq_resp(query)
    |> send()
  end
end
```

The action performed by `iq_resp/2` over the `conn` is creating the response and putting it inside of the connection to be in use by the following `send/1` function. The second parameter of the `iq_resp/2` let us to include the new payload for the result.

For example, if we are implementing a request and we want to send back the information retrieved, we could to use the XML format to write the response:

```elixir
  def get(conn, query) do
    payload = ~x[
      <name>Exampple</name>
      <vsn>#{Application.spec(:exampple)[:vsn]}</vsn>
    ]
    conn
    |> iq_resp([payload])
    |> send()
  end
```

Note that the `~x` sigil is provided by the `Exampple.Xml.Xmlel` module.

We hav different functions to use to generate responses:

- `iq_resp/2`
- `iq_error/2`
- `message_resp/2`
- `message_error/2`

You can check the module to get even more functionalities regarding stanzas.

## Tracing

At the moment we have the possibility to see in the logs (info and error) the amount of time each stanza is taking. To get this information we have to configure properly the output for logger:

```elixir
  config :logger, :console,
    format: "$time $metadata[$level] $levelpad$message\n",
    metadata: [:ellapsed_time, :stanza_id, :stanza_type, :type, :xmlns, :from_jid, :to_jid]
```

The provided metadata available is:

- `ellapsed_time`: the amount of time measured when the stanza came in until the process in charge of the request ended (successfully or due to an error).
- `stanza_id`: the ID which came inside of the stanza.
- `stanza_type`: it could be (mainly): message, presence or iq.
- `type`: the type defined specifically for the stanza: normal, chat, groupchat, set, get, error, ...
- `xmlns`: the XML namespace for the first child inside of the stanza.
- `from_jid`: the JID where the stanza comes from, in a string representation.
- `to_jid`: the JID where the stanza is directed to, in a string representation.

The output will be in the form:

```
00:20:42.717 ellapsed_time=1ms stanza_type=iq type=set [info]  success
```

The time could appear in milliseconds (ms) if the amount is less than 1 second or in seconds (s) otherwise.

## Telemetry

In addition to the logs regarding the stanzas we have the following information to be gathered by telemetry:

- `[:xmpp, :request, :success]`
- `[:xmpp, :request, :failure]`
- `[:xmpp, :request, :timeout]`

All of them register `duration` in milliseconds so, you can get the maximum, minimum, average, percentile and more statistics from the duration of the stanzas inside of the system based on if they are correct (success), wrong (failure) or was not attended (timeout).

## Testing

Finally, but maybe the most important topic, we have facilities to perform the testing part of our component. Thanks to `Exampply.DummyTcp` we can easily use the following macros to test our systems.

The definition of the test should be:

```elixir
use Exampple.ConnCase
```

This macro let us to include and configure the basics to run all of the necessary tests for us and provide us more macros for assertion (see below).

### Configuration

You will need to create a special block to configure the component, as we saw in the very beginning the block is as follows:

```elixir
config :myapp, Exampple.Component,
  domain: "mycomponent.example.com",
  host: "localhost",
  password: "guest",
  ping: 30_000,
  port: 5252,
  set_from: true,
  trimmed: true,
  auto_connect: true,
  tcp_handler: Exampple.DummyTcp
```

As you can see, we configured our own `tcp_handler`. This let us not only test controlling what we are sending but also this let you to change the way the communication with the component is made using a different transport.

### Setup

The setup phase is adding the start of the `DummyTcp` subscription and the start of the `Component` machine. `DummyTcp` is simulating a _handshake_ for us so, it should be properly configured to directly start using it.

### Assertions

The new assertions are the following ones:

- `component_received/1`: let us to inject an stanza inside of the component, like if the server was sending it to us:

```elixir
component_received ~x[
  <iq type='get'>
    <query xmlns='urn:xmpp:ping'/>
  </iq>
]
```

- `assert_stanza_received/1`: similar to `assert_received/1` let us check what has been received to the process. If that is an stanza then it is checking in it against the stanza provided as parameter. Keep in mind this is not waiting for the stanza arrives to the process:

```elixir
assert_stanza_received ~x[
  <iq type='result'/>
]
```

- `assert_stanza_receive/2`: similar to `assert_receive/2`, the second parameter is the time to wait for a response (by default it is 5 seconds). It is waiting for an stanza to be received and it is matching against the stanza provided as the first parameter:

```elixir
assert_stanza_receive ~x[
  <iq type='result'/>
]
```

- `assert_all_stanza_receive/2`: similar to `assert_stanza_receive/2` but is accepting a list of stanzas a first parameter. It is waiting for the time passed as second parameter (or 5 seconds by default). If one stanza is not matching with the rest, it is failing, if one stanza from the list have not its match fails. All of the stanzas have to match.

- `stanza_receive/2`: this is not an assertion but let us to retrieve the stanza directly to handle the information inside of it. As the previous assert it let us to define a timeout.

- `stanza_received/1`: as the previous one, this is a way to retrieve the stanza which should arrived to us previously.

## Collaboration

You can help us to improve and grow this library giving us suggestions using the issues from github, reporting bugs opening an issue or providing a pull request if you want to give us an improvement or a bugfix.

Enjoy!

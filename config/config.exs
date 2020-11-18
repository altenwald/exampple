import Config

if Mix.env() == :test do
  config :exampple, Exampple.Component,
    domain: "test.example.com",
    host: "localhost",
    password: "guest",
    ping: 30_000,
    port: 5252,
    set_from: true,
    trimmed: true,
    tcp_handler: Exampple.DummyTcp

  config :exampple,
    auto_generate_id: false,
    router: TestingRouter

  config :logger, :console,
    format: "$time $metadata[$level] $levelpad$message\n",
    metadata: [:ellapsed_time, :stanza_id, :stanza_type, :type, :xmlns, :from_jid, :to_jid]
end

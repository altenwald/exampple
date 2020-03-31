use Mix.Config

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
end

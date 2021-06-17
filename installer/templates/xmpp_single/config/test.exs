import Config

config :<%= app_name %>, Exampple.Component,
  domain: "comp.example.com",
  host: "example.com",
  password: "guest",
  ping: 30_000,
  port: 5252,
  set_from: true,
  trimmed: true,
  auto_connect: true,
  tcp_handler: Exampple.DummyTcpComponent

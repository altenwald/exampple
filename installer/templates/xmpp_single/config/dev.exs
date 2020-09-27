import Config

config :<%= app_name %>, Exampple.Component,
  domain: "component.localhost",
  host: "localhost",
  password: "guest",
  ping: 30_000,
  port: 5252,
  set_from: true,
  trimmed: true,
  auto_connect: true

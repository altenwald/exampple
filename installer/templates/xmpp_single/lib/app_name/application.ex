defmodule <%= app_module %>.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  def start(_type, _args) do
    children = [<%= if ecto do %>
      # Start the Ecto repository
      <%= app_module %>.Repo,<% end %>
      # Start the XMPP component
      {Exampple, [otp_app: :<%= app_name %>]}
    ]

    opts = [strategy: :one_for_one, name: <%= app_module %>.Supervisor]
    Supervisor.start_link(children, opts)
  end
end

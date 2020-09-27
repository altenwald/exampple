import Config

config :<%= app_name %>,
  <%= if ecto do %>ecto_repos: [<%= app_module %>.Repo],
  <% end %>router: <%= app_module %>.Router

config :logger, :console,
  format: "$time $metadata[$level] $levelpad$message\n",
  metadata: [:ellapsed_time, :stanza_id, :stanza_type, :type]

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{Mix.env()}.exs"

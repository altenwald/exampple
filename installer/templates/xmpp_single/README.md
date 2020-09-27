# <%= app_module %>

To start your Exampple server:

  * Install dependencies with `mix deps.get`
  * Configure the connection to your XMPP Server: `<%= if ecto do %>
  * Create and migrate your database with `mix ecto.setup`<% end %>
  * Start Exampple endpoint with `mix run`

Now you are connected to the XMPP Server and you can send stanzas to your component.

# Used by "mix format"
[
  import_deps: [<%= if ecto do %>:ecto, <% end %>:exampple],<%= if ecto do %>
  inputs: ["*.{ex,exs}", "priv/*/seeds.exs", "{mix,.formatter}.exs", "{config,lib,test}/**/*.{ex,exs}"],
  subdirectories: ["priv/*/migrations"]<% else %>
  inputs: ["*.{ex,exs}", "{mix,.formatter}.exs", "{config,lib,test}/**/*.{ex,exs}"]<% end %>
]

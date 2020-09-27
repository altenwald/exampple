defmodule XmppNew.MixProject do
  use Mix.Project

  @version "0.4.0"
  @github_path "altenwald/exampple"
  @url "https://github.com/#{@github_path}"

  def project do
    [
      app: :xmpp_new,
      start_permanent: Mix.env() == :prod,
      version: @version,
      elixir: "~> 1.9",
      deps: deps(),
      package: [
        maintainers: [
          "Manuel Rubio"
        ],
        licenses: ["LGPL 2.1"],
        links: %{github: @url},
        files: ~w(lib templates mix.exs README.md)
      ],
      source_url: @url,
      docs: docs(),
      description: """
      Exampple project generator.

      Provides a `mix xmpp.new` task to bootstrap a new Elixir application
      with Exampple dependencies.
      """
    ]
  end

  def application do
    [
      extra_applications: [:eex]
    ]
  end

  defp deps do
    [
      {:ex_doc, "~> 0.19.1", only: :dev}
    ]
  end

  defp docs do
    [
      source_url_pattern:
        "https://github.com/#{@github_path}/blob/v#{@version}/installer/%{path}#L%{line}"
    ]
  end
end

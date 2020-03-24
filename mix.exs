defmodule Exampple.MixProject do
  use Mix.Project

  def project do
    [
      app: :exampple,
      version: "0.1.0",
      elixir: "~> 1.9",
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger, :crypto]
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:gen_state_machine, "~> 2.1.0"},
      {:ex_doc, "~> 0.21.3"},
      ## TODO: check if the PR was merged: https://github.com/qcam/saxy/pull/57
      {:saxy, github: "manuel-rubio/saxy", branch: "master"}
    ]
  end
end

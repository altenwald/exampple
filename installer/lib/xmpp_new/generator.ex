defmodule Xmpp.New.Generator do
  @moduledoc false
  import Mix.Generator
  alias Xmpp.New.Project

  @exampple Path.expand("../..", __DIR__)
  @exampple_version Version.parse!(Mix.Project.config()[:version])

  @callback prepare_project(Project.t) :: Project.t
  @callback generate(Project.t) :: Project.t

  defmacro __using__(_env) do
    quote do
      @behaviour unquote(__MODULE__)
      import Mix.Generator
      import unquote(__MODULE__)
      Module.register_attribute(__MODULE__, :templates, accumulate: true)
      @before_compile unquote(__MODULE__)
    end
  end

  defmacro __before_compile__(env) do
    root = Path.expand("../../templates", __DIR__)

    templates_ast =
      for {name, mappings} <- Module.get_attribute(env.module, :templates) do
        for {format, source, _, _} <- mappings, format != :keep do
          path = Path.join(root, source)
          quote do
            @external_resource unquote(path)
            def render(unquote(name), unquote(source)), do: unquote(File.read!(path))
          end
        end
      end

    quote do
      unquote(templates_ast)
      def template_files(name), do: Keyword.fetch!(@templates, name)
    end
  end

  defmacro template(name, mappings) do
    quote do
      @templates {unquote(name), unquote(mappings)}
    end
  end

  def copy_from(%Project{} = project, mod, name) when is_atom(name) do
    mapping = mod.template_files(name)
    for {format, source, project_location, target_path} <- mapping do
      target = Project.join_path(project, project_location, target_path)

      case format do
        :keep ->
          File.mkdir_p!(target)
        :text ->
          create_file(target, mod.render(name, source))
        :config ->
          contents = EEx.eval_string(mod.render(name, source), project.binding, file: source)
          config_inject(Path.dirname(target), Path.basename(target), contents)
        :eex  ->
          contents = EEx.eval_string(mod.render(name, source), project.binding, file: source)
          create_file(target, contents)
      end
    end
  end

  def config_inject(path, file, to_inject) do
    file = Path.join(path, file)

    contents =
      case File.read(file) do
        {:ok, bin} -> bin
        {:error, _} -> "import Config\n"
      end

    with :error <- split_with_self(contents, "use Mix.Config\n"),
         :error <- split_with_self(contents, "import Config\n") do
      Mix.raise ~s[Could not find "use Mix.Config" or "import Config" in #{inspect(file)}]
    else
      [left, middle, right] ->
        File.write!(file, [left, middle, ?\n, String.trim(to_inject), ?\n, right])
    end
  end

  defp split_with_self(contents, text) do
    case :binary.split(contents, text) do
      [left, right] -> [left, text, right]
      [_] -> :error
    end
  end

  def in_umbrella?(app_path) do
    umbrella = Path.expand(Path.join [app_path, "..", ".."])
    mix_path = Path.join(umbrella, "mix.exs")
    apps_path = Path.join(umbrella, "apps")

    File.exists?(mix_path) && File.exists?(apps_path)
  end

  def put_binding(%Project{opts: opts} = project) do
    db            = Keyword.get(opts, :database, "postgres")
    ecto          = Keyword.get(opts, :ecto, false)
    dev           = Keyword.get(opts, :dev, false)
    exampple_path = exampple_path(project, dev)

    # We lowercase the database name because according to the
    # SQL spec, they are case insensitive unless quoted, which
    # means creating a database like FoO is the same as foo in
    # some storages.
    {adapter_app, adapter_module, adapter_config} =
      get_ecto_adapter(db, String.downcase(project.app), project.app_mod)

    adapter_config =
      case Keyword.fetch(opts, :binary_id) do
        {:ok, value} -> Keyword.put_new(adapter_config, :binary_id, value)
        :error -> adapter_config
      end

    version = @exampple_version

    binding = [
      elixir_version: elixir_version(),
      app_name: project.app,
      app_module: inspect(project.app_mod),
      root_app_name: project.root_app,
      root_app_module: inspect(project.root_mod),
      exampple_github_version_tag: "v#{version.major}.#{version.minor}",
      exampple_dep: exampple_dep(exampple_path),
      exampple_path: exampple_path,
      in_umbrella: project.in_umbrella?,
      ecto: ecto,
      adapter_app: adapter_app,
      adapter_module: adapter_module,
      adapter_config: adapter_config,
      generators: nil_if_empty(project.generators ++ adapter_generators(adapter_config)),
      namespaced?: namespaced?(project),
    ]

    %Project{project | binding: binding}
  end

  defp elixir_version do
    System.version()
  end

  defp namespaced?(project) do
    Macro.camelize(project.app) != inspect(project.app_mod)
  end

  def gen_ecto_config(%Project{project_path: project_path, binding: binding}) do
    adapter_config = binding[:adapter_config]

    config_inject project_path, "config/dev.exs", """
    # Configure your database
    config :#{binding[:app_name]}, #{binding[:app_module]}.Repo#{kw_to_config adapter_config[:dev]},
      pool_size: 10
    """

    config_inject project_path, "config/test.exs", """
    # Configure your database
    #
    # The MIX_TEST_PARTITION environment variable can be used
    # to provide built-in test partitioning in CI environment.
    # Run `mix help test` for more information.
    config :#{binding[:app_name]}, #{binding[:app_module]}.Repo#{kw_to_config adapter_config[:test]}
    """

    config_inject project_path, "config/prod.secret.exs", """
    database_url =
      System.get_env("DATABASE_URL") ||
        raise \"""
        environment variable DATABASE_URL is missing.
        For example: ecto://USER:PASS@HOST/DATABASE
        \"""

    config :#{binding[:app_name]}, #{binding[:app_module]}.Repo,
      # ssl: true,
      url: database_url,
      pool_size: String.to_integer(System.get_env("POOL_SIZE") || "10")
    """
  end

  defp get_ecto_adapter("mssql", app, module) do
    {:tds, Ecto.Adapters.Tds, db_config(app, module, "sa", "some!Password")}
  end
  defp get_ecto_adapter("mysql", app, module) do
    {:myxql, Ecto.Adapters.MyXQL, db_config(app, module, "root", "")}
  end
  defp get_ecto_adapter("postgres", app, module) do
    {:postgrex, Ecto.Adapters.Postgres, db_config(app, module, "postgres", "postgres")}
  end
  defp get_ecto_adapter(db, _app, _mod) do
    Mix.raise "Unknown database #{inspect db}"
  end

  defp db_config(app, module, user, pass) do
    [
      dev: [
        username: user,
        password: pass,
        database: "#{app}_dev",
        hostname: "localhost",
        show_sensitive_data_on_connection_error: true
      ],
      test: [
        username: user,
        password: pass,
        database: {:literal, ~s|"#{app}_test\#{System.get_env("MIX_TEST_PARTITION")}"|},
        hostname: "localhost",
        pool: Ecto.Adapters.SQL.Sandbox
      ],
      test_setup_all: "Ecto.Adapters.SQL.Sandbox.mode(#{inspect(module)}.Repo, :manual)",
      test_setup: """
          pid = Ecto.Adapters.SQL.Sandbox.start_owner!(#{inspect(module)}.Repo, shared: not tags[:async])
          on_exit(fn -> Ecto.Adapters.SQL.Sandbox.stop_owner(pid) end)\
      """
    ]
  end

  defp kw_to_config(kw) do
    Enum.map(kw, fn
      {k, {:literal, v}} -> ",\n  #{k}: #{v}"
      {k, v} -> ",\n  #{k}: #{inspect v}"
    end)
  end

  defp adapter_generators(adapter_config) do
    adapter_config
    |> Keyword.take([:binary_id, :migration, :sample_binary_id])
    |> Enum.filter(fn {_, value} -> not is_nil(value) end)
  end

  defp nil_if_empty([]), do: nil
  defp nil_if_empty(other), do: other

  defp exampple_path(%Project{} = project, true) do
    absolute = Path.expand(project.project_path)
    relative = Path.relative_to(absolute, @exampple)

    if absolute == relative do
      Mix.raise "--dev projects must be generated inside exampple directory"
    end

    project
    |> exampple_path_prefix()
    |> Path.join(relative)
    |> Path.split()
    |> Enum.map(fn _ -> ".." end)
    |> Path.join()
  end
  defp exampple_path(%Project{}, false) do
    "deps/exampple"
  end
  defp exampple_path_prefix(%Project{in_umbrella?: true}), do: "../../../"
  defp exampple_path_prefix(%Project{in_umbrella?: false}), do: ".."

  defp exampple_dep("deps/exampple"), do: ~s[{:exampple, "~> #{@exampple_version}"}]
  # defp exampple_dep("deps/exampple"), do: ~s[{:exampple, github: "examppleframework/exampple", override: true}]
  defp exampple_dep(path), do: ~s[{:exampple, path: #{inspect path}, override: true}]
end

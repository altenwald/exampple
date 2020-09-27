defmodule Xmpp.New.Single do
  @moduledoc false
  use Xmpp.New.Generator
  alias Xmpp.New.{Project}

  template :new, [
    {:eex,  "xmpp_single/config/config.exs",             :project, "config/config.exs"},
    {:eex,  "xmpp_single/config/dev.exs",                :project, "config/dev.exs"},
    {:eex,  "xmpp_single/config/test.exs",               :project, "config/test.exs"},
    {:eex,  "xmpp_single/config/prod.exs",               :project, "config/prod.exs"},
    {:eex,  "xmpp_single/lib/app_name/application.ex",   :project, "lib/:app/application.ex"},
    {:eex,  "xmpp_single/lib/app_name/xmpp/ping_controller.ex", :project, "lib/:app/xmpp/ping_controller.ex"},
    {:eex,  "xmpp_single/lib/app_name/xmpp/error_controller.ex", :project, "lib/:app/xmpp/error_controller.ex"},
    {:eex,  "xmpp_single/lib/app_name.ex",               :project, "lib/:app.ex"},
    {:eex,  "xmpp_single/lib/app_name/router.ex",        :project, "lib/:app/router.ex"},
    {:eex,  "xmpp_single/mix.exs",                       :project, "mix.exs"},
    {:eex,  "xmpp_single/README.md",                     :project, "README.md"},
    {:eex,  "xmpp_single/formatter.exs",                 :project, ".formatter.exs"},
    {:eex,  "xmpp_single/gitignore",                     :project, ".gitignore"},
    {:eex,  "xmpp_single/test/test_helper.exs",          :project, "test/test_helper.exs"},
    {:eex,  "xmpp_single/test/xmpp/ping_controller_test.exs", :project, "test/xmpp/ping_controller_test.exs"}
  ]

  template :ecto, [
    {:eex,  "xmpp_ecto/repo.ex",              :app, "lib/:app/repo.ex"},
    {:keep, "xmpp_ecto/priv/repo/migrations", :app, "priv/repo/migrations"},
    {:eex,  "xmpp_ecto/formatter.exs",        :app, "priv/repo/migrations/.formatter.exs"},
    {:eex,  "xmpp_ecto/seeds.exs",            :app, "priv/repo/seeds.exs"},
  ]

  template :bare, []

  def prepare_project(%Project{app: app} = project) when not is_nil(app) do
    %Project{project | project_path: project.base_path}
    |> put_app()
    |> put_root_app()
  end

  defp put_app(%Project{base_path: base_path} = project) do
    %Project{project |
             in_umbrella?: in_umbrella?(base_path),
             app_path: base_path}
  end

  defp put_root_app(%Project{app: app, opts: opts} = project) do
    %Project{project |
             root_app: app,
             root_mod: Module.concat([opts[:module] || Macro.camelize(app)])}
  end

  def generate(%Project{} = project) do
    copy_from project, __MODULE__, :new

    if Project.ecto?(project), do: gen_ecto(project)

    project
  end

  def gen_ecto(project) do
    copy_from project, __MODULE__, :ecto
    gen_ecto_config(project)
  end

  def gen_bare(%Project{} = project) do
    copy_from project, __MODULE__, :bare
  end
end

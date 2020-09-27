Code.require_file "mix_helper.exs", __DIR__

defmodule Mix.Tasks.Xmpp.NewTest do
  use ExUnit.Case, async: false
  import MixHelper
  import ExUnit.CaptureIO

  @app_name "xmpp_mix"

  setup do
    # The shell asks to install deps.
    # We will politely say not.
    send self(), {:mix_shell_input, :yes?, false}
    :ok
  end

  test "returns the version" do
    Mix.Tasks.Xmpp.New.run(["-v"])
    assert_received {:mix_shell, :info, ["Exampple v" <> _]}
  end

  test "new with defaults" do
    in_tmp "new with defaults", fn ->
      Mix.Tasks.Xmpp.New.run([@app_name])

      assert_file "xmpp_mix/README.md"

      assert_file "xmpp_mix/.formatter.exs", fn file ->
        assert file =~ "import_deps: [:exampple]"
        assert file =~ "inputs: [\"*.{ex,exs}\", \"{mix,.formatter}.exs\", \"{config,lib,test}/**/*.{ex,exs}\"]"
        refute file =~ "subdirectories: [\"priv/*/migrations\"]"
      end

      assert_file "xmpp_mix/mix.exs", fn file ->
        assert file =~ "app: :xmpp_mix"
        refute file =~ "deps_path: \"../../deps\""
        refute file =~ "lockfile: \"../../mix.lock\""
      end

      assert_file "xmpp_mix/lib/xmpp_mix/application.ex", ~r/defmodule XmppMix.Application do/
      assert_file "xmpp_mix/lib/xmpp_mix.ex", ~r/defmodule XmppMix do/
      assert_file "xmpp_mix/mix.exs", fn file ->
        assert file =~ "mod: {XmppMix.Application, []}"
        assert file =~ "{:exampple,"
      end

      assert_file "xmpp_mix/test/test_helper.exs"

      assert_file "xmpp_mix/lib/xmpp_mix/xmpp/ping_controller.ex",
                  ~r/defmodule XmppMix.Xmpp.PingController/

      assert_file "xmpp_mix/lib/xmpp_mix/xmpp/error_controller.ex",
                  ~r/defmodule XmppMix.Xmpp.ErrorController/

      assert_file "xmpp_mix/lib/xmpp_mix/router.ex", fn file ->
        assert file =~ "defmodule XmppMix.Router"
        assert file =~ "use Exampple.Router"
      end

      # Install dependencies?
      assert_received {:mix_shell, :yes?, ["\nFetch and install dependencies?"]}

      # No Ecto
      # config = ~r/config :xmpp_mix, XmppMix.Repo,/
      refute File.exists?("xmpp_mix/lib/xmpp_mix/repo.ex")

      assert_file "xmpp_mix/config/config.exs", fn file ->
        refute file =~ "config :xmpp_mix, :generators"
        refute file =~ "ecto_repos:"
      end

      # Instructions
      assert_received {:mix_shell, :info, ["\nWe are almost there" <> _ = msg]}
      assert msg =~ "$ cd xmpp_mix"
      assert msg =~ "$ mix deps.get"

      # assert_received {:mix_shell, :info, ["Then configure your database in config/dev.exs" <> _]}
      # assert_received {:mix_shell, :info, ["Start your Exampple app" <> _]}
    end
  end

  test "new without defaults" do
    in_tmp "new without defaults", fn ->
      Mix.Tasks.Xmpp.New.run([@app_name, "--ecto"])

      # Ecto
      config = ~r/config :xmpp_mix, XmppMix.Repo,/
      assert_file "xmpp_mix/mix.exs", fn file ->
        assert file =~ "{:ecto_sql,"
        assert file =~ "aliases: aliases()"
        assert file =~ "ecto.setup"
        assert file =~ "ecto.reset"
      end
      assert_file "xmpp_mix/config/dev.exs", config
      assert_file "xmpp_mix/config/test.exs", config
      assert_file "xmpp_mix/config/prod.secret.exs", config
      assert_file "xmpp_mix/config/test.exs", ~R/database: "xmpp_mix_test#\{System.get_env\("MIX_TEST_PARTITION"\)\}"/
      assert_file "xmpp_mix/lib/xmpp_mix/repo.ex", ~r"defmodule XmppMix.Repo"
      assert_file "xmpp_mix/priv/repo/seeds.exs", ~r"XmppMix.Repo.insert!"
      assert_file "xmpp_mix/priv/repo/migrations/.formatter.exs", ~r"import_deps: \[:ecto_sql\]"

      assert_file "xmpp_mix/.formatter.exs", fn file ->
        assert file =~ "import_deps: [:ecto, :exampple]"
        assert file =~ "inputs: [\"*.{ex,exs}\", \"priv/*/seeds.exs\", \"{mix,.formatter}.exs\", \"{config,lib,test}/**/*.{ex,exs}\"]"
        assert file =~ "subdirectories:"
      end

      assert_file "xmpp_mix/config/config.exs", fn file ->
        assert file =~ "ecto_repos: [XmppMix.Repo]"
        refute file =~ "namespace: XmppMix"
        refute file =~ "config :xmpp_mix, :generators"
      end

      assert_file "xmpp_mix/mix.exs", &assert(&1 =~ ~r":ecto_sql")

      assert_file "xmpp_mix/config/dev.exs", fn file ->
        assert file =~ "config :xmpp_mix, Exampple.Component,"
      end
    end
  end

  test "new defaults to pg adapter" do
    in_tmp "new defaults to pg adapter", fn ->
      project_path = Path.join(File.cwd!(), "custom_path")
      Mix.Tasks.Xmpp.New.run([project_path, "--ecto"])

      assert_file "custom_path/mix.exs", ":postgrex"
      assert_file "custom_path/config/dev.exs", [~r/username: "postgres"/, ~r/password: "postgres"/, ~r/hostname: "localhost"/]
      assert_file "custom_path/config/test.exs", [~r/username: "postgres"/, ~r/password: "postgres"/, ~r/hostname: "localhost"/]
      assert_file "custom_path/config/prod.secret.exs", [~r/url: database_url/]
      assert_file "custom_path/lib/custom_path/repo.ex", "Ecto.Adapters.Postgres"
    end
  end

  test "new with mysql adapter" do
    in_tmp "new with mysql adapter", fn ->
      project_path = Path.join(File.cwd!(), "custom_path")
      Mix.Tasks.Xmpp.New.run([project_path, "--ecto", "--database", "mysql"])

      assert_file "custom_path/mix.exs", ":myxql"
      assert_file "custom_path/config/dev.exs", [~r/username: "root"/, ~r/password: ""/]
      assert_file "custom_path/config/test.exs", [~r/username: "root"/, ~r/password: ""/]
      assert_file "custom_path/config/prod.secret.exs", [~r/url: database_url/]
      assert_file "custom_path/lib/custom_path/repo.ex", "Ecto.Adapters.MyXQL"
    end
  end

  test "new with mssql adapter" do
    in_tmp "new with mssql adapter", fn ->
      project_path = Path.join(File.cwd!(), "custom_path")
      Mix.Tasks.Xmpp.New.run([project_path, "--ecto", "--database", "mssql"])

      assert_file "custom_path/mix.exs", ":tds"
      assert_file "custom_path/config/dev.exs", [~r/username: "sa"/, ~r/password: "some!Password"/]
      assert_file "custom_path/config/test.exs", [~r/username: "sa"/, ~r/password: "some!Password"/]
      assert_file "custom_path/config/prod.secret.exs", [~r/url: database_url/]
      assert_file "custom_path/lib/custom_path/repo.ex", "Ecto.Adapters.Tds"
    end
  end

  test "new with invalid database adapter" do
    in_tmp "new with invalid database adapter", fn ->
      project_path = Path.join(File.cwd!(), "custom_path")
      assert_raise Mix.Error, ~s(Unknown database "invalid"), fn ->
        Mix.Tasks.Xmpp.New.run([project_path, "--database", "invalid"])
      end
    end
  end

  test "new with invalid args" do
    assert_raise Mix.Error, ~r"Application name must start with a letter and ", fn ->
      Mix.Tasks.Xmpp.New.run ["007invalid"]
    end

    assert_raise Mix.Error, ~r"Module name \w+ is already taken", fn ->
      Mix.Tasks.Xmpp.New.run ["string"]
    end
  end

  test "invalid options" do
    assert_raise Mix.Error, ~r/Invalid option: -d/, fn ->
      Mix.Tasks.Xmpp.New.run(["valid", "-database", "mysql"])
    end
  end

  test "new without args" do
    in_tmp "new without args", fn ->
      assert capture_io(fn -> Mix.Tasks.Xmpp.New.run([]) end) =~
             "Creates a new Exampple project."
    end
  end
end

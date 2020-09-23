defmodule Exampple.Router.Task.Monitor do
  use GenServer, restart: :temporary
  require Logger

  alias Exampple.Component
  alias Exampple.Router.Conn
  alias Exampple.Router.Task, as: RouterTask
  alias Exampple.Xmpp.Stanza

  @syntax_colors [
    number: :yellow,
    atom: :cyan,
    string: :green,
    boolean: :magenta,
    nil: :magenta
  ]

  @format [
    pretty: true,
    structs: true,
    syntax_colors: @syntax_colors
  ]

  defmodule Data do
    defstruct ~w[
      xmlel
      domain
      otp_app
      task_pid
      timer_ref
      timeout
    ]a
  end

  def start_link([xmlel, domain, otp_app, timeout]) do
    GenServer.start_link(__MODULE__, [xmlel, domain, otp_app, timeout])
  end

  def init([xmlel, domain, otp_app, timeout]) do
    Logger.debug("init monitor: #{inspect(xmlel)}")
    {:ok, pid} = RouterTask.start(xmlel, domain, otp_app)
    _monitor_ref = Process.monitor(pid)
    timer_ref = Process.send_after(self(), :timeout, timeout)

    {:ok,
     %Data{
       timeout: timeout,
       xmlel: xmlel,
       domain: domain,
       otp_app: otp_app,
       task_pid: pid,
       timer_ref: timer_ref
     }}
  end

  def handle_info({:DOWN, _ref, :process, pid, reason}, %Data{task_pid: pid} = state)
      when reason in [:normal, :noproc] do
    sucess(state)
    {:stop, :normal, state}
  end

  def handle_info({:DOWN, _ref, :process, pid, reason}, %Data{task_pid: pid} = state) do
    failure(state, reason)
    {:stop, :normal, state}
  end

  def handle_info(:timeout, state) do
    timeout(state)
    {:stop, :etimedout, state}
  end

  defp prepare_logger(%Data{xmlel: xmlel, domain: domain}, diff_time) do
    conn = Conn.new(xmlel, domain)

    Logger.metadata(
      stanza_id: conn.id,
      type: conn.type,
      stanza_type: conn.stanza_type,
      ellapsed_time: diff_time
    )

    conn
  end

  defp sucess(state) do
    diff_time = diff_time(state)
    prepare_logger(state, diff_time)
    Logger.info("success", @format)
  end

  defp failure(state, reason) do
    diff_time = diff_time(state)
    conn = prepare_logger(state, diff_time)
    Logger.error("error: #{inspect(reason)}", @format)

    conn
    |> Stanza.error({"internal-server-error", "en", "An error happened"})
    |> Component.send()
  end

  defp timeout(%Data{task_pid: task_pid, timeout: timeout} = state) do
    RouterTask.stop(task_pid)
    conn = prepare_logger(state, "#{timeout}ms")
    Logger.error("error timeout", @format)

    Stanza.error(
      conn,
      {"remote-server-timeout", "en", "silent error or too much time to process the request"}
    )
  end

  defp diff_time(%Data{timer_ref: timer_ref, timeout: timeout}) do
    msecs = timeout - Process.cancel_timer(timer_ref)

    if msecs >= 1_000 do
      secs = div(msecs, 1_000)

      msecs =
        msecs
        |> rem(1_000)
        |> to_string()
        |> String.pad_leading(3, "0")

      "#{secs}.#{msecs}s"
    else
      "#{msecs}ms"
    end
  end
end

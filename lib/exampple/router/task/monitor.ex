defmodule Exampple.Router.Task.Monitor do
  @moduledoc """
  The monitor starts a task to attend the incoming request,
  when the task is launched a timer is set. The timer is cancelled
  when the task is terminated. If the task crashes, the monitor
  receives a message and replies with an error. In case of timeout
  the request is returning a timeout and the task is terminated.

  In addition to the logs regarding the stanzas we have the following information to be gathered by telemetry:

  - `[:xmpp, :request, :success]`
  - `[:xmpp, :request, :failure]`
  - `[:xmpp, :request, :timeout]`

  All of them register `duration` in milliseconds so, you can get
  the maximum, minimum, average, percentile and more statistics from
  the duration of the stanzas inside of the system based on if they
  are correct (success), wrong (failure) or was not attended (timeout).
  """
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

  @metric_prefix [:xmpp, :request]

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

  @doc """
  Starts the monitor as a server passing the stanza in `xmlel` format,
  the XMPP `domain` for the component and the name of the application
  (`otp_app`) and the `timeout`, all of those parameters as a `list`.

  The `timeout` is needed to know where we have to terminate the task and
  annotate this kind of failure.
  """
  def start_link([xmlel, domain, otp_app, timeout]) do
    GenServer.start_link(__MODULE__, [xmlel, domain, otp_app, timeout])
  end

  @doc false
  @impl GenServer
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

  @doc false
  @impl GenServer
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
      ellapsed_time: diff_time,
      xmlns: conn.xmlns,
      from_jid: to_string(conn.from_jid),
      to_jid: to_string(conn.to_jid)
    )

    conn
  end

  defp sucess(state) do
    {diff_time_txt, diff_time_ms} = diff_time(state)
    conn = prepare_logger(state, diff_time_txt)

    Logger.info("success", @format)

    :telemetry.execute(
      @metric_prefix ++ [:success],
      %{duration: diff_time_ms},
      %{request_ns: conn.xmlns}
    )
  end

  defp failure(state, reason) do
    {diff_time_txt, diff_time_ms} = diff_time(state)
    conn = prepare_logger(state, diff_time_txt)
    Logger.error("error: #{inspect(reason)}", @format)

    :telemetry.execute(
      @metric_prefix ++ [:failure],
      %{duration: diff_time_ms},
      %{request_ns: conn.xmlns}
    )

    conn
    |> Stanza.error({"internal-server-error", "en", "An error happened"})
    |> Component.send()
  end

  defp timeout(%Data{task_pid: task_pid, timeout: timeout} = state) do
    RouterTask.stop(task_pid)
    msecs = human_readable(timeout)
    conn = prepare_logger(state, msecs)
    Logger.error("error timeout", @format)

    :telemetry.execute(
      @metric_prefix ++ [:timeout],
      %{duration: timeout},
      %{request_ns: conn.xmlns}
    )

    Stanza.error(
      conn,
      {"remote-server-timeout", "en", "silent error or too much time to process the request"}
    )
  end

  defp human_readable(msecs) when msecs >= 1_000 do
    secs = div(msecs, 1_000)

    msecs =
      msecs
      |> rem(1_000)
      |> to_string()
      |> String.pad_leading(3, "0")

    "#{secs}.#{msecs}s"
  end

  defp human_readable(msecs), do: "#{msecs}ms"

  # returns {human_readable_time, microseconds}
  defp diff_time(%Data{timer_ref: timer_ref, timeout: timeout}) do
    msecs = timeout - Process.cancel_timer(timer_ref)
    {human_readable(msecs), msecs * 1_000}
  end
end

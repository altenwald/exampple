defmodule TestingTelemetry do
  def attach(metrics, pid \\ self()) do
    :telemetry.attach_many("test-attacher", metrics, &handle_event/4, pid)
  end

  def handle_event(path, measurements, metadata, pid) do
    send(pid, {path, measurements, metadata})
  end
end

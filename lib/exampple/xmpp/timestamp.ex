defmodule Exampple.Xmpp.Timestamp do
  @moduledoc """
  Module to help us to format correctly the date-times.
  Most of the times the date-time should appears in ISO-8601 format
  with a timezone or in UTC. These helpers add the timestamp removing
  the microseconds and milliseconds and adding even letting us to add
  some seconds to the specific time.
  """

  @doc """
  This function let us to show the `datetime` in ISO-8601 format and as
  second parameter we add a `diff` which adds that amount of seconds to
  the datetime.

  Examples:
      iex> {:ok, ts, 0} = DateTime.from_iso8601("2020-04-30T12:00:00Z")
      iex> Exampple.Xmpp.Timestamp.to_string(ts, 3_600)
      "2020-04-30T13:00:00Z"
  """
  def to_string(datetime, diff) do
    datetime
    |> DateTime.add(diff, :second)
    |> Map.put(:microsecond, {0, 0})
    |> DateTime.to_iso8601()
  end

  @doc """
  This function let us to show the `naive` datetime in UTC format.

  Examples:
      iex> {:ok, ts, 0} = DateTime.from_iso8601("2020-04-30T12:00:00Z")
      iex> Exampple.Xmpp.Timestamp.to_utc_string(ts)
      "2020-04-30T12:00:00Z"
  """
  def to_utc_string(naive) do
    naive
    |> DateTime.from_naive!("Etc/UTC")
    |> DateTime.to_iso8601()
  end
end

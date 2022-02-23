defmodule Exampple.Template.Interpolation do
  @moduledoc """
  Interpolation let us interchange a variable inside of a string. The problem with
  the Elixir interpolation is it's made in compilation time which isn't useful when
  we need to perform the same action in runtime.

  This module helps perform interpolations. It's based on `Gettext.Interpolation.Default`.
  """

  @doc """
  Interpolate a string adding the binding variables into the correct places.

  Examples:

      iex> Exampple.Template.Interpolation.interpolate("hello world!", [])
      "hello world!"

      iex> Exampple.Template.Interpolation.interpolate("hello %{name}!", name: "world")
      "hello world!"

      iex> Exampple.Template.Interpolation.interpolate("hello %{none}!", [])
      "hello !"
  """
  def interpolate(string, bindings) do
    start_pattern = :binary.compile_pattern("%{")
    end_pattern = :binary.compile_pattern("}")

    interpolate(string, "", [], start_pattern, end_pattern)
    |> Enum.map(&if is_atom(&1), do: bindings[&1] || "", else: &1)
    |> Enum.reverse()
    |> Enum.join()
  end

  defp interpolate(string, current, acc, start_pattern, end_pattern) do
    case :binary.split(string, start_pattern) do
      [rest] ->
        prepend_if_not_empty(current <> rest, acc)

      [before, "}" <> rest] ->
        current = current <> before <> "%{}"
        interpolate(rest, current, acc, start_pattern, end_pattern)

      [before, binding_and_rest] ->
        case :binary.split(binding_and_rest, end_pattern) do
          [_] ->
            [current <> string | acc]

          [binding, rest] ->
            acc = [String.to_atom(binding) | prepend_if_not_empty(before, acc)]
            interpolate(rest, "", acc, start_pattern, end_pattern)
        end
    end
  end

  defp prepend_if_not_empty("", list), do: list
  defp prepend_if_not_empty(string, list), do: [string | list]
end

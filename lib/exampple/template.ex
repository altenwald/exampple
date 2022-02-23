defmodule Exampple.Template do
  @moduledoc """
  Templates are XML chunks which could be in use for a `Exampple.Client`.
  The template is usually a string which could contain special execution
  code using an escape sintaxis `%{var}`.

  The templates are stored in ETS tables for each node. It was not thought
  for the implementation as a cluster so it will be needed to start it and
  populate it individually for each node.
  """
  alias Exampple.Template.Interpolation

  @type name :: String.t()
  @type key :: atom
  @type content :: String.t() | (Keyword.t() -> String.t())
  @type bindings :: [{key, content}]

  @doc """
  Template requires to be initiated to start working. It's a good idea to start
  it from an Application process because if the process who spawned dies, the
  ETS table also dies.
  """
  @spec init :: :ok
  def init do
    if :ets.info(__MODULE__) == :undefined do
      :ets.new(__MODULE__, [:named_table, :set, :public])
    end

    :ok
  end

  @doc ~S"""
  Use a template registered. This let us to trigger faster stanzas
  when we are working from the shell, developing tests or even when
  we have our code narrowed and focused on the business logic.

  The `name` parameter is the name to lookup the template.
  The `args` are the arguments passed to the function template.

  Examples:

      iex> :ok = Exampple.Template.init()
      iex> Exampple.Template.put("gret", "Hello %{name}!")
      iex> Exampple.Template.render("gret", name: "World")
      {:ok, "Hello World!"}

      iex> :ok = Exampple.Template.init()
      iex> Exampple.Template.put("gret", &"Hello #{&1[:name]}!")
      iex> Exampple.Template.render("gret", name: "World")
      {:ok, "Hello World!"}
  """
  @spec render(name) :: {:ok, content} | {:error, :not_found}
  @spec render(name, bindings) :: {:ok, content} | {:error, :not_found}
  def render(name, bindings \\ []) when is_list(bindings) do
    case get(name) do
      content when is_binary(content) ->
        {:ok, Interpolation.interpolate(content, bindings)}

      content when is_function(content, 1) ->
        {:ok, content.(bindings)}

      nil ->
        {:error, :not_found}
    end
  end

  @doc """
  See `render/1`. It performs the same action but triggering an error
  if the template name wasn't found.

  Examples:

      iex> :ok = Exampple.Template.init()
      iex> Exampple.Template.put("gret", "Hello %{name}!")
      iex> Exampple.Template.render!("gret", name: "World")
      "Hello World!"
  """
  @spec render!(name) :: content
  @spec render!(name, bindings) :: content
  def render!(name, bindings \\ []) do
    case render(name, bindings) do
      {:ok, content} -> content
      {:error, error} -> raise error
    end
  end

  @doc """
  Retrieve a template given the name of the template.
  """
  @spec get(name) :: content | nil
  def get(name) do
    case :ets.lookup(__MODULE__, name) do
      [{^name, content}] -> content
      [] -> nil
    end
  end

  @doc """
  Adds a template to be in use by the process when we call `send_template/2`
  or `send_template/3`. The `name` is the name or PID for the process, the
  `name` is the name we will use storing the template and `xml` is the
  text or function which will generate the stanza.
  """
  @spec put(name, content) :: content
  def put(name, xml) do
    true = :ets.insert(__MODULE__, {name, xml})
    xml
  end
end

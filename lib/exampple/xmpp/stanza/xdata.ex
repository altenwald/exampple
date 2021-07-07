defmodule Exampple.Xmpp.Stanza.Xdata do
  @moduledoc """
  Using Xdata gives the functionality to create and validate forms.
  You can use Xdata to define your own form, create a sent and/or validate
  the form against the rules you defined giving the facilities to translate
  it directly to stanzas or XML string.
  """
  alias Exampple.Xml.Xmlel
  alias Exampple.Xmpp.Jid

  defstruct [
    data: %{},
    xdata_form_type: "form",
    module: nil,
    errors: nil,
    valid?: true
  ]

  defmacro __using__(_args) do
    quote do
      import Exampple.Xmpp.Stanza.Xdata
      Module.register_attribute(__MODULE__, :fields, accumulate: true)
      @before_compile Exampple.Xmpp.Stanza.Xdata
      @instructions nil

      def new(xdata_form_type \\ "form", data \\ %{}) do
        Exampple.Xmpp.Stanza.Xdata.new(__MODULE__)
      end
    end
  end

  def new(form_type_mod, xdata_form_type \\ "form", data \\ %{}) do
    %__MODULE__{
      module: form_type_mod,
      xdata_form_type: xdata_form_type,
      data: data
    }
  end

  @doc false
  defmacro __before_compile__(env) do
    fields = Module.get_attribute(env.module, :fields)
    quote do
      @doc """
      Retrieves all of the fields.
      """
      def get_fields(), do: unquote(fields)

      @doc """
      Retrieves a field based on the name (if exists), otherwise is nil.
      """
      def get_field(var) do
        Enum.find(unquote(fields), & &1.var == var)
      end

      @doc """
      Retrieves the FORM_TYPE for the current form.
      """
      def get_form_type(), do: @form_type

      @doc """
      Retrieves the instructions (if any).
      """
      def get_instructions(), do: @instructions

      @doc """
      Retrieves the title (if any).
      """
      def get_title(), do: @title
    end
  end

  defmacro form(xmlns, title \\ nil, [do: block]) do
    field =
      %{
        var: "FORM_TYPE",
        type: "hidden",
        required: false,
        label: nil,
        desc: nil,
        value: xmlns,
        options: nil
      }
      |> Macro.escape()
      |> Macro.escape()

    quote do
      @title unquote(title)
      @form_type unquote(xmlns)
      @fields unquote(field)
      unquote(block)
    end
  end

  defmacro instructions(text) do
    quote do
      @instructions unquote(text)
    end
  end

  # https://xmpp.org/extensions/xep-0004.html#protocol-fieldtypes
  defp get_type(:boolean), do: "boolean"
  defp get_type(:fixed), do: "fixed"
  defp get_type(:hidden), do: "hidden"
  defp get_type(:jid_multi), do: "jid-multi"
  defp get_type(:jid_single), do: "jid-single"
  defp get_type(:list_multi), do: "list-multi"
  defp get_type(:list_single), do: "list-single"
  defp get_type(:text_multi), do: "text-multi"
  defp get_type(:text_private), do: "text-private"
  defp get_type(:text_single), do: "text-single"
  defp get_type(type) do
    raise """
    Field with type `#{type}` is invalid, please use one of the valid ones.
    Check: https://xmpp.org/extensions/xep-0004.html#protocol-fieldtypes
    """
  end

  def submit(%__MODULE__{xdata_form_type: "form"} = xdata, data) do
    %__MODULE__{xdata | xdata_form_type: "submit"}
    |> cast(data)
    |> validate_form()
  end

  def submit(%__MODULE__{xdata_form_type: "submit"} = xdata, data) do
    %__MODULE__{xdata | xdata_form_type: "result"}
    |> cast(data)
    |> validate_form()
  end

  defmacro field(var, type, args) do
    required = args[:required] || false
    label = args[:label]
    desc = args[:desc]
    value = args[:value]
    type = get_type(type)
    options =
      case type do
        "list-" <> _ -> args[:options]
        _ -> nil
      end
    field =
      %{
        var: var,
        type: type,
        required: required,
        label: label,
        desc: desc,
        value: value,
        options: options
      }
      |> Macro.escape()
      |> Macro.escape()

    quote do
      @fields unquote(field)
    end
  end

  def is_list_type?(module, var) do
    case module.get_field(var) do
      nil -> :error
      field -> String.ends_with?(field.type, "-multi")
    end
  end

  def is_valid_field?(module, var) when is_atom(module) do
    not is_nil(module.get_field(var))
  end

  def parse(form, module) when is_binary(form) do
    {form_str, ""} = Xmlel.parse(form)
    parse(form_str, module)
  end
  def parse(%Xmlel{} = form, module) do
    data =
      for %Xmlel{attrs: %{"var" => var}} = field <- form["field"], is_valid_field?(module, var), into: %{} do
        values =
          for %Xmlel{children: [value]} <- field["value"] || [], do: value

        value =
          case is_list_type?(module, var) do
            true -> values
            false when values == [] -> nil
            false -> hd(values)
          end

        {var, value}
      end

    %__MODULE__{
      module: module,
      data: data,
      xdata_form_type: form.attrs["type"] || "form"
    }
    |> validate_xdata_form_type()
  end

  defp validate_xdata_form_type(%__MODULE__{data: %{"FORM_TYPE" => xmlns}, module: module} = xdata) do
    case module.get_form_type() do
      ^xmlns ->
        xdata

      xmlns ->
        %__MODULE__{xdata | valid?: false}
        |> add_error("form_type_not_matching", "FORM_TYPE #{xmlns} invalid for #{module}")
    end
  end
  defp validate_xdata_form_type(%__MODULE__{} = xdata) do
    %__MODULE__{xdata | valid?: false}
    |> add_error("form_type_missing", "FORM_TYPE is missing and is required")
  end

  def validate_form(%__MODULE__{data: data, module: module} = xdata) do
    module.get_fields()
    |> Enum.reduce(xdata, fn %{var: var, type: type, required: is_required} = field, acc ->
      is_multi = String.ends_with?(type, "-multi")
      case data[var] do
        nil when is_required -> add_error(acc, "required", "#{var} is required")
        "" when is_required -> add_error(acc, "required", "#{var} is required")
        nil -> acc
        "" -> acc
        [_|_] when is_multi -> acc
        [_|_] -> add_error(acc, "no-multi", "#{var} doesn't support multi values")
        _value when is_multi -> acc
        _value -> acc
      end
      |> validate_type(field, data[var])
    end)
    |> validate_xdata_form_type()
  end

  defp validate_type(xdata, _, nil), do: xdata
  defp validate_type(xdata, %{type: "hidden"}, _), do: xdata
  defp validate_type(xdata, %{type: "text-single"}, _), do: xdata
  defp validate_type(xdata, %{type: "text-multi"}, _), do: xdata
  defp validate_type(xdata, %{var: var, type: "fixed"}, fixed) do
    if String.contains?(fixed, ["\r", "\n"]) do
      add_error(xdata, "invalid-fixed", "#{var} fixed cannot contains \\r\\n")
    else
      xdata
    end
  end
  defp validate_type(xdata, %{var: var, type: "jid-single"}, jid) do
    case Jid.parse(jid) do
      %Jid{} -> xdata
      "" -> xdata
      {:error, :enojid} ->
        add_error(xdata, "invalid-jid", "#{var} has invalid JID `#{jid}`")
    end
  end
  defp validate_type(xdata, %{var: var, type: "jid-multi"}, jids) do
    Enum.reduce(jids, xdata, fn jid, acc ->
      case Jid.parse(jid) do
        %Jid{} -> acc
        "" -> acc
        {:error, :enojid} ->
          add_error(acc, "invalid-jid", "#{var} has invalid JID `#{jid}`")
      end
    end)
  end
  defp validate_type(xdata, %{var: var, type: "list-single", options: options}, option) do
    if List.keyfind(options, option, 1) do
      xdata
    else
      add_error(xdata, "invalid-option", "#{var} use invalid option `#{option}`")
    end
  end
  defp validate_type(xdata, %{var: var, type: "list-multi", options: options}, option_multi) do
    Enum.reduce(option_multi, xdata, fn option, acc ->
      if List.keyfind(options, option, 1) do
        acc
      else
        add_error(acc, "invalid-option", "#{var} use invalid option `#{option}`")
      end
    end)
  end

  def cast(%__MODULE__{module: module} = xdata, %{} = data) do
    data = Map.put(data, "FORM_TYPE", module.get_form_type())
    module.get_fields()
    |> Enum.reduce(xdata, fn %{var: var, type: type}, acc ->
      is_multi = String.ends_with?(type, "-multi")
      case data[var] do
        nil -> acc
        [_|_] = values when is_multi -> add_data(acc, var, values)
        [value|_] -> add_data(acc, var, value)
        value when is_multi -> add_data(acc, var, [value])
        value -> add_data(acc, var, value)
      end
    end)
  end

  def add_data(%__MODULE__{data: data} = xdata, var, value) do
    %__MODULE__{xdata | data: Map.put(data, var, value)}
  end

  def add_error(%__MODULE__{errors: errors} = xdata, name, text) do
    error = %{name: name, text: text}
    %__MODULE__{xdata | errors: [error|errors || []]}
  end

  defimpl String.Chars, for: __MODULE__ do
    alias Exampple.Xml.Xmlel
    alias Exampple.Xmpp.Stanza.Xdata

    defp maybe_add(_tag, nil), do: []
    defp maybe_add(tag, title), do: [Xmlel.new(tag, %{}, [title])]

    defp maybe_add_required(%{required: false}), do: []
    defp maybe_add_required(%{var: "FORM_TYPE"}), do: []
    defp maybe_add_required(%{required: true}), do: [Xmlel.new("required")]

    defp maybe_add_value(%{}, value) when not is_nil(value) do
      [Xmlel.new("value", %{}, [value])]
    end
    defp maybe_add_value(%{value: nil}, nil), do: []
    defp maybe_add_value(%{value: value}, nil), do: [Xmlel.new("value", %{}, [value])]

    defp maybe_add_options(%{options: nil}), do: []
    defp maybe_add_options(%{options: options}) do
      for {name, id} <- options do
        Xmlel.new("option", %{"label" => name}, [Xmlel.new("value", %{}, [id])])
      end
    end

    defp maybe_add_label(attrs, %{label: nil}), do: attrs
    defp maybe_add_label(attrs, %{label: label}) do
      Map.put(attrs, "label", label)
    end

    defp get_final_type(%Xdata{valid?: false}), do: "cancel"
    defp get_final_type(%Xdata{xdata_form_type: type}), do: type

    @doc """
    Converts a Xdata form into the XML representation.
    """
    def to_string(form) do
      Xmlel.new("x", %{"type" => get_final_type(form), "xmlns" => "jabber:x:data"},
        for field <- form.module.get_fields() do
          value = form.data[field.var]
          Xmlel.new(
            "field",
            maybe_add_label(%{"type" => field.type, "var" => field.var}, field),
            maybe_add_required(field) ++
            maybe_add_value(field, value) ++
            maybe_add_options(field)
          )
        end ++
        maybe_add("instructions", form.module.get_instructions()) ++
        maybe_add("title", form.module.get_title())
        |> Enum.reverse()
      )
      |> Kernel.to_string()
    end
  end
end

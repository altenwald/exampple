defmodule Exampple.Xmpp.Stanza.Xdata do
  @moduledoc """
  Using Xdata gives the functionality to create and validate forms.
  You can use Xdata to define your own form, create a sent and/or validate
  the form against the rules you defined giving the facilities to translate
  it directly to stanzas or XML string.
  """
  alias Exampple.Xml.Xmlel
  alias Exampple.Xmpp.Jid
  alias Exampple.Xmpp.Stanza.Xdata.FieldError
  alias __MODULE__

  @type t() :: %__MODULE__{
          data: map(),
          xdata_form_type: String.t(),
          module: module(),
          errors: nil | [map()],
          valid?: boolean()
        }

  defstruct data: %{},
            xdata_form_type: "form",
            module: nil,
            errors: nil,
            valid?: true

  @doc false
  defmacro __using__(_args) do
    quote do
      import Exampple.Xmpp.Stanza.Xdata
      Module.register_attribute(__MODULE__, :fields, accumulate: true)
      @before_compile Exampple.Xmpp.Stanza.Xdata
      @instructions nil

      @doc """
      Creates a new Xdata structure. See more information in `Exampple.Xmpp.Stanza.Xdata`.
      """
      @spec new(String.t(), map()) :: Exampple.Xmpp.Stanza.Xdata.t()
      def new(xdata_form_type \\ "form", data \\ %{})

      def new("form", data) when map_size(data) == 0 do
        Exampple.Xmpp.Stanza.Xdata.new(__MODULE__)
      end

      def new(xdata_form_type, data) when map_size(data) == 0 do
        Exampple.Xmpp.Stanza.Xdata.new(__MODULE__, xdata_form_type)
      end

      def new(xdata_form_type, data) do
        Exampple.Xmpp.Stanza.Xdata.new(__MODULE__, xdata_form_type)
        |> Exampple.Xmpp.Stanza.Xdata.cast(data)
      end

      @doc """
      Check if a field inside of the definition is multi or not.
      See more information in `Exampple.Xmpp.Stanza.Xdata`.
      """
      @spec is_multi_type?(String.t()) :: :error | boolean()
      def is_multi_type?(var) do
        Exampple.Xmpp.Stanza.Xdata.is_multi_type?(__MODULE__, var)
      end

      @doc """
      Check if a field is existing into the form definition.
      See more information in `Exampple.Xmpp.Stanza.Xdata` .
      """
      @spec has_field?(String.t()) :: boolean()
      def has_field?(var) do
        Exampple.Xmpp.Stanza.Xdata.has_field?(__MODULE__, var)
      end

      @doc """
      Parse a form prefixing the module to the current one.
      See more information in `Exampple.Xmpp.Stanza.Xdata`.
      """
      @spec parse(String.t() | Exampple.Xml.Xmlel.t()) :: Exampple.Xmpp.Stanza.Xdata.t()
      def parse(form) do
        Exampple.Xmpp.Stanza.Xdata.parse(form, __MODULE__)
      end
    end
  end

  @doc """
  Creates a new Xdata structure. It let us define the module which has
  the definition for the xdata, the type attribute for the form tag. The possible
  types for the xdata form are the following ones:

  - `form` (default): The form-processing entity is asking the form-submitting
    entity to complete a form.
  - `submit`: The form-submitting entity is submitting data to the form-processing
    entity. The submission MAY include fields that were not provided in the empty
    form, but the form-processing entity MUST ignore any fields that it does not
    understand. Furthermore, the submission MAY omit fields not marked with <required/>
    by the form-processing entity.
  - `cancel`: The form-submitting entity has cancelled submission of data to the form
    processing entity.
  - `result`: The form-processing entity is returning data (e.g., search results) to
    the form-submitting entity, or the data is a generic data set.

  See further here: <https://xmpp.org/extensions/xep-0004.html#protocol-formtypes>
  """
  @spec new(module(), String.t()) :: t()
  def new(form_type_mod, xdata_form_type \\ "form") do
    %__MODULE__{
      module: form_type_mod,
      xdata_form_type: xdata_form_type
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
        Enum.find(unquote(fields), &(&1.var == var))
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

  @doc """
  Creates a form definition inside of a module which is using
  the `Exampple.Xmpp.Stanza.Xdata` module. The parameters are the following:

  - `xmlns` (required) the namespace which will be inserted as `FORM_TYPE` data
    inside of the form.
  - `title` (optional) the title which will be apearing as the `<title/>` tag
    inside of the form.

  We have to define a configuration block where we will use other macros like
  `field` or `instructions`, see below.
  """
  defmacro form(xmlns, title \\ nil, do: block) do
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

  @doc """
  Creates the instructions definition inside of the form definition. It accepts
  only one parameter which is the text regarding of the instructions to be included
  inside of the form.
  """
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
    raise FieldError, """
    Field with type `#{type}` is invalid, please use one of the valid ones.
    Check: https://xmpp.org/extensions/xep-0004.html#protocol-fieldtypes
    """
  end

  @doc """
  Creates a field definition inside of the form definition. The field is the
  most important part of the form and they have two missions: specifiy what will
  be useful for the form to be retrieved from the input map (cast) and the kind
  of data the field supports to ensure we are using the correct values (validation).

  The field accepts two main arguments:

  - `var` is the name of the field.
  - `type` is the type of the field. The types are defined into the [XEP-004].
    and they are defined below.

  Types we can use:

  - `:boolean`: we can set the values as `true` or `1` and `false` or `0`.
  - `:fixed`: this is not data itself, it is in use to define a separator into the form.
  - `:hidden`: data which will be sent to the user, and it should back as is from user.
  - `:jid_multi`: possible to send one or more JID as values.
  - `:jid_single`: a JID.
  - `:list_multi`: possible to send one or more elements defined into a list of options.
  - `:list_single`: possible to send one element from a defined list of options.
  - `:text_multi`: possible to send one or more text values.
  - `:text_private`: tells to the interface to _obscure_ the input, special for password inputs.
  - `:text_single`: generic text entry. The most common.

  The other options we can add to the specification are:

  - `required` (boolean) if the value is required. Default to `false`.
  - `label` (text) a label which will be shown into an interface.
  - `desc` (text) the description of the input.
  - `value` is the default value indeed.
  - `options` is a list of 2-element tuples which are `{name, id}` letting use to define
    as the name (the visual definition of the value) and `id` as the element which we use:

    ```
    [{"Male", "M"}, {"Female", "F"}]
    ```

  [XEP-0004]: https://xmpp.org/extensions/xep-0004.html
  """
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

  @doc """
  Submitting a form is the action to get a previous form and proceed to
  the following step. The steps which follows usually a xdata form are the
  following ones:

  - `form`: we receive the form with this type and the specification of the
    fields. It gives us information about what we should to fill up.
  - `submit`: when we get a `form` and perform the submit function, it is
    changed to `submit`. We have to provide the specific data for the
    form as well. It performs first a `cast` and then a `validation`. If
    everything is fine, then we have prepared a form to be in use.
  - `result`: if we receive a `submit` form and we want to reply it, it is
    changed to `result` and we can provide more information inside or modify
    the information to report to the submitter what was changed or added.

  See `cast/2` and `validate_form/2` for further information.
  """
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

  @doc """
  Let us know if a field from a definition specified as the first parameter,
  exists and it's a multi value. We can receive a boolean value if the field
  is found, otherwise we will receive the atom `:error`. If the boolean value
  is true, that is meaning the type is `list-multi`, `text-multi` or `jid-multi`,
  otherwise we receive false.
  """
  @spec is_multi_type?(module(), String.t()) :: :error | boolean()
  def is_multi_type?(module, var) do
    case module.get_field(var) do
      nil -> :error
      field -> String.ends_with?(field.type, "-multi")
    end
  end

  @spec is_multi_type?(map()) :: boolean()
  def is_multi_type?(%{type: type}) do
    String.ends_with?(type, "-multi")
  end

  @doc """
  Let us know if the field exists inside of a form definition.
  """
  @spec has_field?(module(), String.t()) :: boolean()
  def has_field?(module, var) when is_atom(module) do
    not is_nil(module.get_field(var))
  end

  @doc """
  Transform a XML representation of a xdata form into a Xdata structure. We have
  to provide the data to be transformed in string or Xmlel structure representations
  as first parameter. The second parameter let us define the module which have the
  definitions of the form.
  """
  @spec parse(String.t() | Xmlel.t(), module()) :: t()
  def parse(form, module) when is_binary(form) do
    {form_str, ""} = Xmlel.parse(form)
    parse(form_str, module)
  end

  def parse(%Xmlel{} = form, module) do
    data =
      for %Xmlel{attrs: %{"var" => var}} = field <- form["field"],
          has_field?(module, var),
          into: %{} do
        values = for %Xmlel{children: [value]} <- field["value"] || [], do: value

        value =
          case module.is_multi_type?(var) do
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

  defp validate_xdata_form_type(%__MODULE__{data: %{"FORM_TYPE" => form_type}} = xdata)
       when form_type in [nil, ""] do
    add_error(xdata, "form_type_missing", "FORM_TYPE is missing and is required")
  end

  defp validate_xdata_form_type(
         %__MODULE__{data: %{"FORM_TYPE" => xmlns}, module: module} = xdata
       ) do
    case module.get_form_type() do
      ^xmlns ->
        xdata

      right_xmlns ->
        mod_str =
          case to_string(module) do
            "Elixir." <> mod_str -> mod_str
            mod_str -> mod_str
          end

        add_error(
          xdata,
          "form_type_not_matching",
          "FORM_TYPE #{xmlns} != #{right_xmlns} invalid for #{mod_str}"
        )
    end
  end

  defp validate_xdata_form_type(%__MODULE__{} = xdata) do
    add_error(xdata, "form_type_missing", "FORM_TYPE is missing and is required")
  end

  @doc """
  Performs the validation of the form (or Xdata structure). It's checking the data
  stored inside previously using `cast/2` and then perform changes into the _errors_
  and _valid?_ internal values.

  After the running of the validation we'll get the transformed Xdata structure and
  we can use `valid?` value inside of the structure to know if the validation was
  fine or it detects errors.
  """
  @spec validate_form(t()) :: t()
  def validate_form(%__MODULE__{data: data, module: module} = xdata) do
    module.get_fields()
    |> Enum.reduce(xdata, fn %{var: var, required: is_required} = field, acc ->
      is_multi = is_multi_type?(field)

      case data[var] do
        nil when is_required -> add_error(acc, "required", "#{var} is required")
        "" when is_required -> add_error(acc, "required", "#{var} is required")
        nil -> acc
        "" -> acc
        [_ | _] when is_multi -> acc
        [_ | _] -> add_error(acc, "no-multi", "#{var} doesn't support multi values")
        _value when is_multi -> acc
        _value -> acc
      end
      |> validate_type(field, data[var])
    end)
    |> validate_xdata_form_type()
  end

  defp validate_type(xdata, _, nil), do: xdata

  defp validate_type(xdata, %{var: var, type: "boolean"}, value) do
    value
    |> String.downcase()
    |> String.trim()
    |> case do
      "true" -> xdata
      "false" -> xdata
      "0" -> xdata
      "1" -> xdata
      _ -> add_error(xdata, "invalid-boolean", "#{var} boolean is invalid: #{value}")
    end
  end

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
      %Jid{} ->
        xdata

      "" ->
        xdata

      {:error, :enojid} ->
        add_error(xdata, "invalid-jid", "#{var} has invalid JID `#{jid}`")
    end
  end

  defp validate_type(xdata, %{var: var, type: "jid-multi"}, jids) do
    Enum.reduce(jids, xdata, fn jid, acc ->
      case Jid.parse(jid) do
        %Jid{} ->
          acc

        "" ->
          acc

        {:error, :enojid} ->
          add_error(acc, "invalid-jid", "#{var} has invalid JID `#{jid}`")
      end
    end)
  end

  defp validate_type(xdata, %{var: var, type: "list-single", options: options}, option) do
    case List.keyfind(options, option, 1) do
      nil when option in [nil, ""] ->
        add_error(xdata, "invalid-option", "#{var} use invalid empty option")

      nil ->
        add_error(xdata, "invalid-option", "#{var} use invalid option `#{option}`")

      _option ->
        xdata
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

  @doc """
  Performs the inclusion of the data from the map into the second parameter
  into the first one. It's not performing validation, it's only checking which
  values are legal to be included and the way (using the types) we could include
  them.
  """
  @spec cast(t(), map()) :: t()
  def cast(%__MODULE__{module: module} = xdata, %{} = data) do
    data =
      if Map.has_key?(data, "FORM_TYPE") do
        data
      else
        Map.put(data, "FORM_TYPE", module.get_form_type())
      end

    module.get_fields()
    |> Enum.reduce(xdata, fn %{var: var} = field, acc ->
      is_multi = is_multi_type?(field)

      case data[var] do
        nil -> acc
        [_ | _] = values when is_multi -> add_data(acc, var, values)
        [value | _] -> add_data(acc, var, value)
        value when is_multi -> add_data(acc, var, [value])
        value -> add_data(acc, var, value)
      end
    end)
  end

  @doc """
  Add a value inside of the data structure. In difference of `cast/2` this is
  forcing to be included and it's not checking the types.
  """
  @spec add_data(t(), String.t(), any()) :: t()
  def add_data(%__MODULE__{data: data} = xdata, var, value) do
    %__MODULE__{xdata | data: Map.put(data, var, value)}
  end

  @doc """
  Add an error definition inside of the structure and set the `valid?` value
  to `false`. It needs the name of the error and the definition (or text)
  for the error.
  """
  @spec add_error(t(), String.t(), String.t()) :: t()
  def add_error(%__MODULE__{errors: errors} = xdata, name, text) do
    error = %{name: name, text: text}
    %__MODULE__{xdata | valid?: false, errors: [error | errors || []]}
  end

  defimpl Exampple.Xml, for: __MODULE__ do
    alias Exampple.Xml.Xmlel
    alias Exampple.Xmpp.Stanza.Xdata

    defp maybe_add(_tag, nil), do: []
    defp maybe_add(tag, title), do: [Xmlel.new(tag, %{}, [title])]

    defp maybe_add_required(%{required: false}), do: []
    defp maybe_add_required(%{var: "FORM_TYPE"}), do: []
    defp maybe_add_required(%{required: true}), do: [Xmlel.new("required")]

    defp maybe_add_value(%{}, value) when is_binary(value) do
      [Xmlel.new("value", %{}, [value])]
    end

    defp maybe_add_value(%{}, values) when is_list(values) do
      for value <- values do
        Xmlel.new("value", %{}, [value])
      end
    end

    defp maybe_add_value(%{value: nil}, nil), do: []

    defp maybe_add_value(%{value: value}, nil) when is_binary(value) do
      [Xmlel.new("value", %{}, [value])]
    end

    defp maybe_add_value(%{value: values}, nil) when is_list(values) do
      for value <- values do
        Xmlel.new("value", %{}, [value])
      end
    end

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
    def to_xmlel(form) do
      Xmlel.new(
        "x",
        %{"type" => get_final_type(form), "xmlns" => "jabber:x:data"},
        (for field <- form.module.get_fields() do
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
           maybe_add("title", form.module.get_title()))
        |> Enum.reverse()
      )
    end
  end

  defimpl String.Chars, for: __MODULE__ do
    @doc """
    Converts a Xdata form into the XML string representation.
    """
    def to_string(form) do
      form
      |> Exampple.Xml.to_xmlel()
      |> Kernel.to_string()
    end
  end
end

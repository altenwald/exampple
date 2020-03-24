defmodule Exampple.Xml.Parser.Simple do
  @moduledoc false

  @behaviour Saxy.Handler

  alias Exampple.Xml.Xmlel

  def handle_event(:start_document, _prolog, _state) do
    {:ok, []}
  end

  def handle_event(:start_element, {tag_name, attributes}, stack) do
    tag = %Xmlel{name: tag_name, attrs: Enum.into(attributes, %{})}
    {:ok, [tag | stack]}
  end

  def handle_event(:characters, chars, [%Xmlel{children: content} = xmlel | stack]) do
    current = %Xmlel{xmlel | children: [chars | content]}
    {:ok, [current | stack]}
  end

  def handle_event(:end_element, tag_name, [%Xmlel{name: tag_name} = xmlel | stack]) do
    current = %Xmlel{xmlel | children: Enum.reverse(xmlel.children)}

    case stack do
      [] ->
        {:ok, [current]}

      [%Xmlel{children: parent_content} = parent | rest] ->
        parent = %Xmlel{parent | children: [current | parent_content]}
        {:ok, [parent | rest]}
    end
  end

  def handle_event(:end_document, _, state) do
    {:ok, state}
  end
end

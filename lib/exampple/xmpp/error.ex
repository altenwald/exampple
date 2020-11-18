defmodule Exampple.Xmpp.Error do
  @moduledoc """
  Help defining an error module which have all of the information of
  errors and a function for raise them correctly.

  You can trigger these errors whenever inside of your controller and
  these scales until the component to return the corresponding error.
  """
  defexception message: "service-unavailable",
               lang: "en",
               type: "cancel",
               reason: "Something wrong happened"

  @doc """
  Raise the error with the information provided.
  """
  defmacro fire_up!(message, reason, lang \\ "en") do
    type = get_error(message)

    quote do
      raise(unquote(__MODULE__),
        message: unquote(message),
        lang: unquote(lang),
        type: unquote(type),
        reason: unquote(reason)
      )
    end
  end

  @doc false
  ## took from: https://xmpp.org/extensions/xep-0086.html
  def get_error("gone"), do: "modify"
  def get_error("redirect"), do: "modify"
  def get_error("bad-request"), do: "modify"
  def get_error("jid-malformed"), do: "modify"
  def get_error("unexpected-request"), do: "wait"
  def get_error("not-authorized"), do: "auth"
  def get_error("payment-required"), do: "auth"
  def get_error("forbidden"), do: "auth"
  def get_error("item-not-found"), do: "cancel"
  def get_error("recipient-unavailable"), do: "cancel"
  def get_error("remote-server-not-found"), do: "cancel"
  def get_error("not-allowed"), do: "cancel"
  def get_error("not-acceptable"), do: "modify"
  def get_error("registration-required"), do: "auth"
  def get_error("subscription-required"), do: "auth"
  def get_error("conflict"), do: "cancel"
  def get_error("internal-server-error"), do: "wait"
  def get_error("resource-constraint"), do: "wait"
  def get_error("feature-not-implemented"), do: "cancel"
  def get_error("service-unavailable"), do: "cancel"
  def get_error("remote-server-timeout"), do: "wait"
end

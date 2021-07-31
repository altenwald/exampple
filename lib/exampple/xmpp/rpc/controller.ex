defmodule Exampple.Xmpp.Rpc.Controller do
  use Exampple.Component

  alias Exampple.Xml.Xmlel
  alias Exampple.Xml.Rpc, as: XmlRpc

  def rpc(conn, [query]) do
    with [method_call | _] <- query["methodCall"],
         {method_name, params} <- XmlRpc.decode_request(method_call),
         module when not is_nil(module) <- Application.get_env(:exampple, :rpc),
         true <- check_method_name(module, method_name, length(params)) do
      response =
        apply(module, String.to_atom(method_name), params)
        |> create_result()

      conn
      |> iq_resp([response])
      |> send()
    else
      false ->
        conn
        |> error({"item-not-found", "en", "method not found"})
        |> send()

      nil ->
        conn
        |> error({"bad-request", "en", "methodCall tag not found"})
        |> send()
    end
  end

  def rpc(conn, query) do
    conn
    |> error({"bad-request", "en", "invalid query, you must include only one query tag"})
    |> send()
  end

  defp check_method_name(module, fun, arity) do
    {fun, arity} in Enum.map(module.module_info(:exports), fn {f, a} -> {to_string(f), a} end)
  end

  defp create_result(result) do
    Xmlel.new("query", %{"xmlns" => "jabber:iq:rpc"}, [
      XmlRpc.encode_response(result)
    ])
  end
end

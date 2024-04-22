defmodule Helpers.SafeLuerl do
  @moduledoc """
  A wrapper for Luerl to better handle exceptions
  """

  @spec safe_do(any(), String.t()) :: {:error, any()} | {:ok, %{lua_state: any(), result: any()}}
  def safe_do(lua_state, lua_request) do
    {[result], lua_state} = Luerl.do(lua_state, lua_request)
    {:ok, %{result: result, lua_state: lua_state}}
  rescue
    e ->
      case e do
        %{original: {:lua_error, reason, _details}} -> {:error, reason}
        %{term: {:error, reason, _details}} -> {:error, reason}
        _ -> reraise e, __STACKTRACE__
      end
  end
end

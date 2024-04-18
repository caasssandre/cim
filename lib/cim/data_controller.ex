defmodule Cim.DataController do
  @moduledoc """
  Controller to handle CRUD operations
  """
  import Plug.Conn

  @spec show(Plug.Conn.t()) :: Plug.Conn.t()
  def show(conn) do
    case Cim.Server.get_data(%{database_name: conn.params["database"], key: conn.params["key"]}) do
      {:ok, value} ->
        conn
        # |> put_resp_content_type("application/octet-stream")
        |> send_resp(200, value)

      {:data_not_found, reason} ->
        send_resp(conn, 404, reason)

      {:error, reason} ->
        send_resp(conn, 500, reason)
    end
  end

  @spec create(Plug.Conn.t()) :: Plug.Conn.t()
  def create(conn) do
    with {:ok, body} <- get_request_body(conn),
         {:ok, _response} <-
           Cim.Server.push(%{
             database_name: conn.params["database"],
             key: conn.params["key"],
             body: body
           }) do
      send_resp(conn, 200, "")
    else
      {:error, reason} -> send_resp(conn, 500, "Error: #{reason}")
    end
  end

  @spec delete_key(Plug.Conn.t()) :: Plug.Conn.t()
  def delete_key(conn) do
    case Cim.Server.delete_key(%{database_name: conn.params["database"], key: conn.params["key"]}) do
      {:ok, _response} -> send_resp(conn, 200, "")
      {:data_not_found, message} -> send_resp(conn, 404, message)
      {:error, message} -> send_resp(conn, 500, message)
    end
  end

  @spec delete_database(Plug.Conn.t()) :: Plug.Conn.t()
  def delete_database(conn) do
    case Cim.Server.delete_database(%{database_name: conn.params["database"]}) do
      {:ok, _response} -> send_resp(conn, 200, "")
      {:data_not_found, message} -> send_resp(conn, 404, message)
      {:error, message} -> send_resp(conn, 500, message)
    end
  end

  @spec execute_lua_request(Plug.Conn.t()) :: Plug.Conn.t()
  def execute_lua_request(conn) do
    with {:ok, body} <- get_request_body(conn),
         {:ok, _response} <-
           Cim.Server.execute_lua_request(%{lua_request: body}) do
      conn
      # |> put_resp_content_type("application/octet-stream")
      |> send_resp(200, "")
    else
      {:error, reason} ->
        send_resp(conn, 500, "Error: #{reason}")
    end
  end

  defp get_request_body(conn) do
    case Plug.Conn.read_body(conn, length: :infinity) do
      {:ok, body, _conn} ->
        {:ok, body}

      {:error, reason} ->
        {:error, reason}
    end
  end
end

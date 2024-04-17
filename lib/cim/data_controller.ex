defmodule Cim.DataController do
  @moduledoc """
  Controller to handle CRUD operations
  """
  import Plug.Conn

  def show(conn) do
    case Cim.Server.get(%{database_name: conn.params["database"], key: conn.params["key"]}) do
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

  def create(conn) do
    with {:ok, body} <- get_request_body(conn),
         {:ok, _response} <-
           Cim.Server.push(%{
             database_name: conn.params["database"],
             key: conn.params["key"],
             body: body
           }) do
      conn
      # |> put_resp_content_type("application/octet-stream")
      |> send_resp(200, "")
    else
      {:error, reason} ->
        send_resp(conn, 500, "Error: #{reason}")
    end
  end

  def delete_key(conn) do
    case Cim.Server.delete_key(%{database_name: conn.params["database"], key: conn.params["key"]}) do
      {:ok, _response} ->
        conn
        # |> put_resp_content_type("application/octet-stream")
        |> send_resp(200, "")

      {:data_not_found, message} ->
        send_resp(conn, 404, message)

      {:error, message} ->
        send_resp(conn, 500, message)
    end
  end

  def delete_database(conn) do
    case Cim.Server.delete_database(%{database_name: conn.params["database"]}) do
      {:ok, _response} ->
        conn
        # |> put_resp_content_type("application/octet-stream")
        |> send_resp(200, "")

      {:data_not_found, message} ->
        send_resp(conn, 404, message)

      {:error, message} ->
        send_resp(conn, 500, message)
    end
  end

  defp get_request_body(conn) do
    case Plug.Conn.read_body(conn, length: :infinity) do
      {:ok, body, _conn} ->
        {:ok, body}

      {:error, reason, _conn} ->
        {:error, reason}
    end
  end
end

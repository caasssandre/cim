defmodule Cim.DataController do
  import Plug.Conn

  def show(conn) do
    # case Cim.Server.get(%{key: conn.params["key"]}) do
    case Cim.Server.get(conn.params) do
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
    case get_request_body(conn) do
      {:ok, body} ->
        # add error handling here
        Cim.Server.push(%{path: conn.params, body: body})
        send_resp(conn, 200, "")

      {:error, reason} ->
        send_resp(conn, 500, "Error: #{reason}")
    end
  end

  def delete(conn) do
    case Cim.Server.delete(conn.params) do
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

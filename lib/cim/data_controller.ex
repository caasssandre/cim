defmodule Cim.DataController do
  @moduledoc """
  Controller to handle CRUD operations on the datastore
  """
  import Plug.Conn

  alias Cim.Datastore

  @spec show(Plug.Conn.t()) :: Plug.Conn.t()
  def show(%{params: params} = conn) do
    case Datastore.get(params["database"], params["key"]) do
      {:ok, value} ->
        conn
        |> put_resp_content_type("application/octet-stream")
        |> send_resp(200, value)

      {:error, :not_found} ->
        send_resp(conn, 404, "The database or key do not exist")

        # _ ->
        #   send_resp(conn, 500, "Error: ")
    end
  end

  @spec create(Plug.Conn.t()) :: Plug.Conn.t()
  def create(%{params: params} = conn) do
    with {:ok, body, _conn} <- read_body(conn),
         :ok <-
           Datastore.put(params["database"], params["key"], body) do
      send_resp(conn, 200, "")
    else
      {:error, reason} -> send_resp(conn, 500, "Error: #{reason}")
    end
  end

  @spec delete_key(Plug.Conn.t()) :: Plug.Conn.t()
  def delete_key(%{params: params} = conn) do
    case Datastore.delete_key(params["database"], params["key"]) do
      :ok ->
        send_resp(conn, 200, "")

      {:error, :not_found} ->
        send_resp(conn, 404, "The database or key do not exist")
        # {:error, reason} -> send_resp(conn, 500, "Error: #{reason}")
    end
  end

  @spec delete_database(Plug.Conn.t()) :: Plug.Conn.t()
  def delete_database(%{params: params} = conn) do
    case Datastore.delete_database(params["database"]) do
      :ok ->
        send_resp(conn, 200, "")

      {:error, :not_found} ->
        send_resp(conn, 404, "The database does not exist")
        # {:error, reason} -> send_resp(conn, 500, "Error: #{reason}")
    end
  end

  @spec execute_lua(Plug.Conn.t()) :: Plug.Conn.t()
  def execute_lua(%{params: params} = conn) do
    with {:ok, body, _conn} <- read_body(conn),
         {:ok, response} <- Datastore.execute_lua(params["database"], body) do
      conn
      |> put_resp_content_type("application/octet-stream")
      |> send_resp(200, response)
    else
      {:error, :not_found} ->
        send_resp(conn, 404, "The database or key do not exist")

      {:error, {:lua, reason}} ->
        send_resp(conn, 404, "Error: #{inspect(reason)}")

        # {:error, reason} ->
        #   send_resp(conn, 500, "Error: #{inspect(reason)}")
    end
  end
end

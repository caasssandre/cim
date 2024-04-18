defmodule Cim.DataControllerTest do
  use ExUnit.Case, async: true
  use Plug.Test
  use Mimic

  alias Cim.Router
  alias Cim.Datastore

  @opts Router.init([])

  describe "GET /show" do
    test "cannot find the key" do
      expect(Datastore, :get, fn database, key ->
        assert  "my_database"= database
        assert  "my_key" = key
        {:not_found, "The database or key do not exist"}
      end)

      conn =
        :get
        |> conn("/my_database/my_key")
        |> Router.call(@opts)

      assert conn.state == :sent
      assert conn.status == 404
      assert conn.resp_body == "The database or key do not exist"
    end

    test "finds the key and returns 200" do
      expect(Datastore, :get, fn database, key ->
        assert  "my_database"= database
        assert  "my_key" = key
        {:ok, "test"}
      end)

      conn =
        :get
        |> conn("/my_database/my_key")
        |> Router.call(@opts)

      assert conn.state == :sent
      assert conn.status == 200
      assert conn.resp_body == "test"
    end

    test "with a server error" do
      expect(Datastore, :get, fn database, key ->
        assert  "my_database"= database
        assert  "my_key" = key
        {:error, "internal server error"}
      end)

      conn =
        :get
        |> conn("/my_database/my_key")
        |> Router.call(@opts)

      assert conn.state == :sent
      assert conn.status == 500
      assert conn.resp_body == "Error: internal server error"
    end
  end

  describe "PUT /create" do
    test "responds with 200 and no content" do
      expect(Datastore, :push, fn database, key, body ->
        assert  "my_database"= database
        assert  "my_key" = key
        assert  "test" = body
        {:ok, :new_data_added}
      end)

      conn =
        :put
        |> conn("/my_database/my_key", "test")
        |> Router.call(@opts)

      assert conn.state == :sent
      assert conn.status == 200
      assert conn.resp_body == ""
    end

    test "with a server error" do
      expect(Datastore, :push, fn database, key, body ->
        assert  "my_database"= database
        assert  "my_key" = key
        assert  "test" = body
        {:error, "internal server error"}
      end)

      conn =
        :put
        |> conn("/my_database/my_key", "test")
        |> Router.call(@opts)

      assert conn.state == :sent
      assert conn.status == 500
      assert conn.resp_body == "Error: internal server error"
    end
  end
end

defmodule Cim.ServerTest do
  use ExUnit.Case, async: true

  alias Cim.Server

  setup do
    pid = start_supervised!({Server, name: nil})
    [pid: pid]
  end

  describe "get/2" do
    test "returns the correct value for the database and key", %{pid: pid} do
      Server.push(pid, %{database_name: "test_database", key: "test_key", body: "test"})
      assert {:ok, "test"} = Server.get(pid, %{database_name: "test_database", key: "test_key"})
    end

    test "returns thand error if the database/key is not present", %{pid: pid} do
      assert {:data_not_found, "The database or key do not exist"} = Server.get(pid, %{database_name: "test_database", key: "test_key"})
    end
  end

  describe "push/2" do
    test "returns :ok", %{pid: pid} do
      assert {:ok, :new_data_added} = Server.push(pid, %{database_name: "test_database", key: "test_key", body: "test"})
    end
  end

  describe "delete_key/2" do
    test "deletes the correct key", %{pid: pid} do
      Server.push(pid, %{database_name: "test_database", key: "test_key", body: "test"})
      Server.push(pid, %{database_name: "test_database", key: "test_key_two", body: "test"})
      Server.push(pid, %{database_name: "test_database_two", key: "test_key", body: "test"})

      assert {:ok, :key_deleted} = Server.delete_key(pid, %{database_name: "test_database", key: "test_key"})
      assert {:ok, "test"} = Server.get(pid, %{database_name: "test_database", key: "test_key_two"})
      assert {:ok, "test"} = Server.get(pid, %{database_name: "test_database_two", key: "test_key"})
      assert {:data_not_found, "The database or key do not exist"} = Server.get(pid, %{database_name: "test_database", key: "test_key"})
    end
  end

  describe "delete_database/2" do
    test "deletes the correct database", %{pid: pid} do
      Server.push(pid, %{database_name: "test_database", key: "test_key", body: "test"})
      Server.push(pid, %{database_name: "test_database", key: "test_key_two", body: "test"})
      Server.push(pid, %{database_name: "test_database_two", key: "test_key", body: "test"})

      assert {:ok, :database_deleted} = Server.delete_database(pid, %{database_name: "test_database"})
      assert {:data_not_found, "The database or key do not exist"} = Server.get(pid, %{database_name: "test_database", key: "test_key_two"})
      assert {:ok, "test"} = Server.get(pid, %{database_name: "test_database_two", key: "test_key"})
      assert {:data_not_found, "The database or key do not exist"} = Server.get(pid, %{database_name: "test_database", key: "test_key"})
    end
  end
end

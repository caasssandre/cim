defmodule Cim.DatastoreTest do
  use ExUnit.Case, async: true

  alias Cim.Datastore

  setup do
    pid = start_supervised!({Datastore, name: nil})
    [pid: pid]
  end

  describe "get/2" do
    test "returns the correct value for the database and key", %{pid: pid} do
      Datastore.push(pid, "test_database", "test_key", "test")
      assert {:ok, "test"} = Datastore.get(pid, "test_database", "test_key")
    end

    test "returns an error if the database/key is not present", %{pid: pid} do
      assert {:not_found, "The database or key do not exist"} =
               Datastore.get(pid, "test_database", "test_key")
    end
  end

  describe "push/2" do
    test "returns :ok", %{pid: pid} do
      assert {:ok, :new_data_added} =
               Datastore.push(pid, "test_database", "test_key", "test")
    end
  end

  describe "delete_key/2" do
    test "deletes the correct key", %{pid: pid} do
      Datastore.push(pid, "test_database", "test_key", "test")
      Datastore.push(pid, "test_database", "test_key_two", "test")
      Datastore.push(pid, "test_database_two", "test_key", "test")

      assert {:ok, :key_deleted} =
               Datastore.delete_key(pid, "test_database", "test_key")

      assert {:ok, "test"} =
               Datastore.get(pid, "test_database", "test_key_two")

      assert {:ok, "test"} =
               Datastore.get(pid, "test_database_two", "test_key")

      assert {:not_found, "The database or key do not exist"} =
               Datastore.get(pid, "test_database", "test_key")
    end
  end

  describe "delete_database/2" do
    test "deletes the correct database", %{pid: pid} do
      Datastore.push(pid, "test_database", "test_key", "test")
      Datastore.push(pid, "test_database", "test_key_two", "test")
      Datastore.push(pid, "test_database_two", "test_key", "test")

      assert {:ok, :database_deleted} =
               Datastore.delete_database(pid, "test_database")

      assert {:not_found, "The database or key do not exist"} =
               Datastore.get(pid, "test_database", "test_key_two")

      assert {:ok, "test"} =
               Datastore.get(pid, "test_database_two", "test_key")

      assert {:not_found, "The database or key do not exist"} =
               Datastore.get(pid, "test_database", "test_key")
    end
  end
end

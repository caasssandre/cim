defmodule Cim.DatastoreTest do
  use ExUnit.Case, async: true

  alias Cim.Datastore

  setup do
    pid = start_supervised!({Datastore, name: nil})
    [pid: pid]
  end

  describe "get/2" do
    test "returns the correct value for the database and key", %{pid: pid} do
      Datastore.put(pid, "test_database", "test_key", "test")
      assert {:ok, "test"} = Datastore.get(pid, "test_database", "test_key")
    end

    test "returns an error if the database/key is not present", %{pid: pid} do
      assert {:error, :not_found} =
               Datastore.get(pid, "test_database", "test_key")
    end
  end

  describe "push/2" do
    test "returns :ok", %{pid: pid} do
      assert :ok = Datastore.put(pid, "test_database", "test_key", "test")
    end
  end

  describe "delete_key/2" do
    test "deletes the correct key", %{pid: pid} do
      Datastore.put(pid, "test_database", "test_key", "test")
      Datastore.put(pid, "test_database", "test_key_two", "test_two")
      Datastore.put(pid, "test_database_two", "test_key", "test_three")

      assert :ok =
               Datastore.delete_key(pid, "test_database", "test_key")

      assert {:ok, "test_two"} =
               Datastore.get(pid, "test_database", "test_key_two")

      assert {:ok, "test_three"} =
               Datastore.get(pid, "test_database_two", "test_key")

      assert {:error, :not_found} =
               Datastore.get(pid, "test_database", "test_key")
    end
  end

  describe "delete_database/2" do
    test "deletes the correct database", %{pid: pid} do
      Datastore.put(pid, "test_database", "test_key", "test")
      Datastore.put(pid, "test_database", "test_key_two", "test")
      Datastore.put(pid, "test_database_two", "test_key", "test")

      assert :ok =
               Datastore.delete_database(pid, "test_database")

      assert {:error, :not_found} =
               Datastore.get(pid, "test_database", "test_key_two")

      assert {:ok, "test"} =
               Datastore.get(pid, "test_database_two", "test_key")

      assert {:error, :not_found} =
               Datastore.get(pid, "test_database", "test_key")
    end
  end

  describe "execute_lua/3" do
    test "cim.read returns the value for the key", %{pid: pid} do
      Datastore.put(pid, "test_database", "test_key", "test")
      Datastore.put(pid, "test_database", "test_key_2", "test_2")

      assert {:ok, "test"} =
               Datastore.execute_lua(pid, "test_database", "return cim.read('test_key')")

      assert {:ok, "test_2"} =
               Datastore.execute_lua(
                 pid,
                 "test_database",
                 "return cim.read('test_key_2')"
               )
    end

    test "cim.read returns an empty string if the key is not found", %{pid: pid} do
      Datastore.put(pid, "test_database", "test_key", "test")

      assert {:ok, nil} =
               Datastore.execute_lua(pid, "test_database", "return cim.read('bad_key')")
    end

    test "cim.write adds the correct key value pair to the database", %{pid: pid} do
      Datastore.put(pid, "test_database", "test_key", "test")

      assert {:ok, "new_value"} =
               Datastore.execute_lua(
                 pid,
                 "test_database",
                 "cim.write('new_key', 'new_value') return cim.read('new_key')"
               )
    end

    test "cim.write overwrites an existing value", %{pid: pid} do
      Datastore.put(pid, "test_database", "test_key", "test")

      assert {:ok, "new_value"} =
               Datastore.execute_lua(
                 pid,
                 "test_database",
                 "cim.write('test_key', 'new_value') return cim.read('test_key')"
               )
    end

    test "cim.delete deletes the correct key value pair to the database", %{pid: pid} do
      Datastore.put(pid, "test_database", "test_key", "test")

      assert {:ok, nil} =
               Datastore.execute_lua(
                 pid,
                 "test_database",
                 "cim.delete('test_key') return cim.read('test_key')"
               )
    end

    test "returns an error if the database is not found", %{pid: pid} do
      assert {:error, :not_found} =
               Datastore.execute_lua(
                 pid,
                 "test_database",
                 "cim.write('new_key', 'new_value')"
               )

      assert {:error, :not_found} =
               Datastore.execute_lua(
                 pid,
                 "test_database",
                 "cim.read('new_key')"
               )

      assert {:error, :not_found} =
               Datastore.execute_lua(
                 pid,
                 "test_database",
                 "cim.delete('new_key')"
               )
    end

    test "returns an error if the lua code is invalid", %{pid: pid} do
      Datastore.put(pid, "test_database", "test_key", "test")

      assert {:error, {:lua, {:undefined_function, nil}}} =
               Datastore.execute_lua(
                 pid,
                 "test_database",
                 "cim.bad_function('new_key', 'new_value')"
               )

      assert {:error,
              {:lua,
               [
                 {1, :luerl_parse,
                  [~c"syntax error before: ", [[60, 60, ~c"\"new_key\"", 62, 62]]]}
               ]}} =
               Datastore.execute_lua(
                 pid,
                 "test_database",
                 "cim.'new_key', 'new_value'"
               )
    end
  end
end

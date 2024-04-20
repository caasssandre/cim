defmodule Cim.Datastore do
  @moduledoc """
  A configurable state to hold key/value pairs within databases.

  The state has the following structure:
  %{database_one: %{key: "value"},
    database_two: %{key: "value", other_key: "other_value"}}

  Values can be read, added or deleted.
  Databases can be deleted.
  """
  use GenServer

  @spec start_link(keyword()) :: :ignore | {:error, any()} | {:ok, pid()}
  def start_link(opts) do
    name = Keyword.get(opts, :name, __MODULE__)
    GenServer.start_link(__MODULE__, [], name: name)
  end

  @spec push(any(), binary(), binary()) :: any()
  def push(pid \\ __MODULE__, database_name, key, body) do
    GenServer.call(pid, {:push, %{database_name: database_name, key: key, value: body}})
  end

  def delete_key(pid \\ __MODULE__, database_name, key) do
    GenServer.call(pid, {:delete_key, %{database_name: database_name, key: key}})
  end

  @spec delete_database(pid(), binary()) :: any()
  def delete_database(pid \\ __MODULE__, database_name) do
    GenServer.call(pid, {:delete_database, %{database_name: database_name}})
  end

  @spec get(pid(), binary(), binary()) :: any()
  def get(pid \\ __MODULE__, database_name, key) do
    GenServer.call(pid, {:get, %{database_name: database_name, key: key}})
  end

  def execute_lua_request(pid \\ __MODULE__, database_name, lua_request) do
    GenServer.call(
      pid,
      {:execute_lua_request, %{database_name: database_name, lua_request: lua_request}}
    )
  end

  @impl GenServer
  def init(_opts) do
    {:ok, %{"database" => %{"world" => "hello", "key" => "valueasdf"}}}
  end

  @impl GenServer
  def handle_call({:push, %{database_name: database_name, key: key, value: value}}, _from, state) do
    case Map.fetch(state, database_name) do
      {:ok, _database} ->
        {:reply, {:ok, :new_data_added}, put_in(state, [database_name, key], value)}

      :error ->
        updated_state = Map.put(state, database_name, %{key => value})
        {:reply, {:ok, :new_data_added}, updated_state}
    end
  end

  def handle_call({:get, %{database_name: database_name, key: key}}, _from, state) do
    value_from(state, database_name, key)
  end

  def handle_call({:delete_key, %{database_name: database_name, key: key}}, _from, state) do
    with {:ok, database} <- Map.fetch(state, database_name),
         {:ok, _value} <- Map.fetch(database, key) do
      updated_database = Map.delete(database, key)
      updated_state = Map.put(state, database_name, updated_database)
      {:reply, {:ok, :key_deleted}, updated_state}
    else
      :error -> {:reply, {:not_found, "The database or key do not exist"}, state}
    end
  end

  def handle_call({:delete_database, %{database_name: database_name}}, _from, state) do
    case Map.fetch(state, database_name) do
      {:ok, _database} ->
        updated_state = Map.delete(state, database_name)
        {:reply, {:ok, :database_deleted}, updated_state}

      :error ->
        {:reply, {:not_found, "The database does not exist"}, state}
    end
  end

  def handle_call(
        {:execute_lua_request, %{lua_request: lua_request, database_name: database_name}},
        _from,
        datastore_state
      ) do
    case Map.fetch(datastore_state, database_name) do
      {:ok, database} -> execute_lua_on_existing_db(database, lua_request, datastore_state, database_name)
      :error -> {:reply, {:not_found, "The database does not exist"}, datastore_state}
    end
  end

  defp execute_lua_on_existing_db(database, lua_request, datastore_state, database_name) do
    lua_state = init_lua_functions()
    |> Luerl.set_table(["datastore_state"], database)

    {_result, luerl_state_2} =
      Luerl.do(
        lua_state,
        lua_request
      )

      {retrieved_value, _lua_state} = Luerl.get_table(luerl_state_2, ["return_value"])
      {ds_state_new, _lua_state} = Luerl.get_table(luerl_state_2, ["datastore_state"])

      dbg retrieved_value
      dbg put_in(datastore_state, [database_name], Map.new(ds_state_new))

      {:reply, {:ok, retrieved_value}, put_in(datastore_state, [database_name], Map.new(ds_state_new))}
  end

  defp value_from(state, database_name, key) do
    case get_in(state, [database_name, key]) do
      nil -> {:reply, {:not_found, "The database or key do not exist"}, state}
      value -> {:reply, {:ok, value}, state}
    end
  end

  defp init_lua_functions() do
    Luerl.init()
    |> Luerl.set_table(["cim_read"], init_lua_read())
    |> Luerl.set_table(["cim_write"], init_lua_write())
    # |> Luerl.set_table(["cim_return_value"], init_return_value())
  end

  defp init_lua_read() do
    fn [key], lua_state ->
      {ds_state, _lua_state} = Luerl.get_table(lua_state, ["datastore_state"])
      {_key, found_value} = Enum.find(ds_state, fn {ds_key, _value} -> ds_key == key end)
      luerl_state_new = Luerl.set_table(lua_state, ["return_value"], found_value)
      {[found_value], luerl_state_new}
    end
  end

  defp init_lua_write() do
    fn [key, value], lua_state ->
      {ds_state, _lua_state} = Luerl.get_table(lua_state, ["datastore_state"])
      new_ds_state = [{key, value}] ++ ds_state
      luerl_state_new = Luerl.set_table(lua_state, ["datastore_state"], new_ds_state)
      {[""], luerl_state_new}
    end
  end
end

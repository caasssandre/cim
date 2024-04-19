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
    {:ok, %{"cass" => "hello"}}
  end

  # updated_state = put_in(state, [database_name, key], value)
  # {:reply, {:ok, :new_data_added}, updated_state}
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
    with {:ok, database} <- Map.fetch(state, database_name),
         {:ok, value} <- Map.fetch(database, key) do
      {:reply, {:ok, value}, state}
    else
      :error -> {:reply, {:not_found, "The database or key do not exist"}, state}
    end
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
        {:execute_lua_request, %{lua_request: lua_request, database_name: _database_name}},
        _from,
        state
      ) do
    lua_state = Luerl.init()

    lua_read = fn([key], lua_state_i) -> {[key <> " G"], lua_state_i} end

    lua_state_1 = Luerl.set_table(lua_state, ["cim_read"], lua_read)

    {result, _luerl_state_2} = Luerl.do(lua_state_1, lua_request)
    dbg result
    {:reply, {:ok, "We're doing lua stuff"}, state}
  end
end
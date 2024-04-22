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
  alias Cim.Lua

  @cim_database "__cim_database"

  @spec start_link(keyword()) :: :ignore | {:error, any()} | {:ok, pid()}
  def start_link(opts) do
    name = Keyword.get(opts, :name, __MODULE__)
    GenServer.start_link(__MODULE__, [], name: name)
  end

  @spec put(String.t(), String.t(), binary()) :: {:ok, :new_data_added}
  def put(pid \\ __MODULE__, database_name, key, body) do
    GenServer.call(pid, {:put, %{database_name: database_name, key: key, value: body}})
  end

  @spec delete_key(String.t(), String.t()) :: any()
  def delete_key(pid \\ __MODULE__, database_name, key) do
    GenServer.call(pid, {:delete_key, %{database_name: database_name, key: key}})
  end

  @spec delete_database(String.t()) :: any()
  def delete_database(pid \\ __MODULE__, database_name) do
    GenServer.call(pid, {:delete_database, %{database_name: database_name}})
  end

  @spec get(String.t(), String.t()) :: any()
  def get(pid \\ __MODULE__, database_name, key) do
    GenServer.call(pid, {:get, %{database_name: database_name, key: key}})
  end

  @spec execute_lua_request(String.t(), String.t()) :: any()
  def execute_lua_request(pid \\ __MODULE__, database_name, lua_request) do
    GenServer.call(
      pid,
      {:execute_lua_request, %{database_name: database_name, lua_request: lua_request}}
    )
  end

  @impl GenServer
  def init(_opts) do
    {:ok, %{}}
  end

  @impl GenServer
  def handle_call({:put, %{database_name: database_name, key: key, value: value}}, _from, state) do
    case Map.fetch(state, database_name) do
      {:ok, _database} ->
        {:reply, {:ok, :new_data_added}, put_in(state, [database_name, key], value)}

      :error ->
        updated_state = Map.put(state, database_name, %{key => value})
        {:reply, {:ok, :new_data_added}, updated_state}
    end
  end

  def handle_call({:get, %{database_name: database_name, key: key}}, _from, state) do
    case get_in(state, [database_name, key]) do
      nil -> {:reply, {:not_found, "The database or key do not exist"}, state}
      value -> {:reply, {:ok, value}, state}
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
        {:execute_lua_request, %{lua_request: lua_request, database_name: database_name}},
        _from,
        state
      ) do
    with {:ok, database} <- Map.fetch(state, database_name),
         {:ok, %{value: value, updated_database: updated_database}} <-
           execute_lua_request_on_db(database, lua_request) do
      {:reply, {:ok, value || ""}, put_in(state, [database_name], Map.new(updated_database))}
    else
      :error -> {:reply, {:not_found, "The database does not exist"}, state}
      {:lua_code_error, reason} -> {:reply, {:lua_code_error, reason}, state}
    end
  end

  defp execute_lua_request_on_db(database, lua_request) do
    updated_lua_state =
      set_functions_in_lua_state()
      |> Luerl.set_table([@cim_database], database)

    case Lua.safe_do(updated_lua_state, lua_request) do
      {:ok, %{result: result, lua_state: lua_state}} ->
        {updated_database, _lua_state} = Luerl.get_table(lua_state, [@cim_database])
        {:ok, %{value: result, updated_database: updated_database}}

      {:error, reason} ->
        {:lua_code_error, reason}
    end
  end

  defp set_functions_in_lua_state() do
    Luerl.init()
    |> Luerl.set_table(["cim"], %{})
    |> Luerl.set_table(["cim", "read"], set_lua_read())
    |> Luerl.set_table(["cim", "write"], set_lua_write())
    |> Luerl.set_table(["cim", "delete"], set_lua_delete())
  end

  defp set_lua_read() do
    fn [key], lua_state ->
      {database, _lua_state} = Luerl.get_table(lua_state, [@cim_database])

      found_value =
        Enum.find_value(database, fn
          {^key, value} -> value
          _ -> nil
        end)

      {[found_value], lua_state}
    end
  end

  defp set_lua_write() do
    fn [key, value], lua_state ->
      {database, _lua_state} = Luerl.get_table(lua_state, [@cim_database])
      updated_database = [{key, value}] ++ database
      updated_lua_state = Luerl.set_table(lua_state, [@cim_database], updated_database)
      {[value], updated_lua_state}
    end
  end

  defp set_lua_delete() do
    fn [key], lua_state ->
      {database, _lua_state} = Luerl.get_table(lua_state, [@cim_database])

      {[{_key, value}], updated_database} =
        Enum.split_with(database, fn {database_key, _value} -> database_key == key end)

      updated_lua_state = Luerl.set_table(lua_state, [@cim_database], updated_database)
      {[value], updated_lua_state}
    end
  end
end

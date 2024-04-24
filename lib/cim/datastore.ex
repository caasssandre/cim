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

  @spec put(atom() | pid(), String.t(), String.t(), binary()) :: :ok
  def put(pid \\ __MODULE__, database_name, key, body) do
    GenServer.call(pid, {:put, %{database_name: database_name, key: key, value: body}})
  end

  @spec delete_key(atom() | pid(), String.t(), String.t()) :: :ok | {:error, :not_found}
  def delete_key(pid \\ __MODULE__, database_name, key) do
    GenServer.call(pid, {:delete_key, %{database_name: database_name, key: key}})
  end

  @spec delete_database(atom() | pid(), String.t()) :: :ok | {:error, :not_found}
  def delete_database(pid \\ __MODULE__, database_name) do
    GenServer.call(pid, {:delete_database, %{database_name: database_name}})
  end

  @spec get(atom() | pid(), String.t(), String.t()) ::
          {:ok, binary()} | {:error, :not_found} | {:error, {:lua, any()}}
  def get(pid \\ __MODULE__, database_name, key) do
    GenServer.call(pid, {:get, %{database_name: database_name, key: key}})
  end

  @spec execute_lua(atom() | pid(), String.t(), String.t()) ::
          {:ok, binary() | nil} | {:error, :not_found} | {:error, {:lua, any()}}
  def execute_lua(pid \\ __MODULE__, database_name, lua_code) do
    GenServer.call(
      pid,
      {:execute_lua, %{database_name: database_name, lua_code: lua_code}}
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
        {:reply, :ok, put_in(state, [database_name, key], value)}

      :error ->
        updated_state = Map.put(state, database_name, %{key => value})
        {:reply, :ok, updated_state}
    end
  end

  def handle_call({:get, %{database_name: database_name, key: key}}, _from, state) do
    case get_in(state, [database_name, key]) do
      nil -> {:reply, {:error, :not_found}, state}
      value -> {:reply, {:ok, value}, state}
    end
  end

  def handle_call({:delete_key, %{database_name: database_name, key: key}}, _from, state) do
    with {:ok, database} <- Map.fetch(state, database_name),
         true <- Map.has_key?(database, key) do
      updated_state = Map.put(state, database_name, Map.delete(database, key))
      {:reply, :ok, updated_state}
    else
      :error -> {:reply, {:error, :not_found}, state}
      false -> {:reply, {:error, :not_found}, state}
    end
  end

  def handle_call({:delete_database, %{database_name: database_name}}, _from, state) do
    case Map.fetch(state, database_name) do
      {:ok, _database} ->
        updated_state = Map.delete(state, database_name)
        {:reply, :ok, updated_state}

      :error ->
        {:reply, {:error, :not_found}, state}
    end
  end

  def handle_call(
        {:execute_lua, %{lua_code: lua_code, database_name: database_name}},
        _from,
        state
      ) do
    with {:ok, database} <- Map.fetch(state, database_name),
         {:ok, %{value: value, updated_database: updated_database}} <-
           execute_lua_on_db(database, lua_code) do
      {:reply, {:ok, value}, Map.put(state, database_name, Map.new(updated_database))}
    else
      :error -> {:reply, {:error, :not_found}, state}
      {:error, {:lua, reason}} -> {:reply, {:error, {:lua, reason}}, state}
    end
  end

  defp execute_lua_on_db(database, lua_code) do
    updated_lua_state =
      set_functions_in_lua_state()
      |> Luerl.set_table([@cim_database], database)

    case Lua.safe_do(updated_lua_state, lua_code) do
      {:ok, %{result: result, lua_state: lua_state}} ->
        {updated_database, _lua_state} = Luerl.get_table(lua_state, [@cim_database])
        {:ok, %{value: result, updated_database: updated_database}}

      {:error, reason} ->
        {:error, {:lua, reason}}
    end
  end

  defp set_functions_in_lua_state() do
    Luerl.init()
    |> Luerl.set_table(["cim"], %{})
    |> Luerl.set_table(["cim", "read"], lua_read())
    |> Luerl.set_table(["cim", "write"], lua_write())
    |> Luerl.set_table(["cim", "delete"], lua_delete())
  end

  defp lua_read() do
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

  defp lua_write() do
    fn [key, value], lua_state ->
      {database, _lua_state} = Luerl.get_table(lua_state, [@cim_database])

      updated_database = Map.new(database) |> Map.put(key, value)
      updated_lua_state = Luerl.set_table(lua_state, [@cim_database], updated_database)
      {[value], updated_lua_state}
    end
  end

  defp lua_delete() do
    fn [key], lua_state ->
      {database, _lua_state} = Luerl.get_table(lua_state, [@cim_database])

      {[{_key, value}], updated_database} =
        Enum.split_with(database, fn {database_key, _value} -> database_key == key end)

      updated_lua_state = Luerl.set_table(lua_state, [@cim_database], updated_database)
      {[value], updated_lua_state}
    end
  end
end

defmodule Cim.Server do
  @moduledoc """
  A configurable state to hold key/value pairs within databases.

  The state has the following structure:
  %{database_one: %{key: value},
    database_two: %{key, value, other_key: other_value}}

  Values can be read, added or deleted.
  Databases can be deleted.
  """
  use GenServer

  @spec start_link(keyword()) :: :ignore | {:error, any()} | {:ok, pid()}
  def start_link(opts) do
    name = Keyword.get(opts, :name, __MODULE__)
    GenServer.start_link(__MODULE__, [], name: name)
  end

  @spec push(%{
          :body => any(),
          :database_name => binary(),
          :key => binary(),
          optional(pid()) => any()
        }) :: any()
  def push(pid \\ __MODULE__, %{database_name: database_name, key: key, body: body}) do
    GenServer.call(pid, {:push, %{database_name: database_name, key: key, value: body}})
  end

  @spec delete_key(%{:database_name => binary(), :key => binary(), optional(pid()) => any()}) ::
          any()
  def delete_key(pid \\ __MODULE__, %{database_name: database_name, key: key}) do
    GenServer.call(pid, {:delete_key, %{database_name: database_name, key: key}})
  end

  @spec delete_database(%{:database_name => binary(), optional(pid()) => any()}) :: any()
  def delete_database(pid \\ __MODULE__, %{database_name: database_name}) do
    GenServer.call(pid, {:delete_database, %{database_name: database_name}})
  end

  @spec get_data(%{:database_name => binary(), :key => binary(), optional(pid()) => any()}) ::
          any()
  def get_data(pid \\ __MODULE__, %{database_name: database_name, key: key}) do
    GenServer.call(pid, {:get_data, %{database_name: database_name, key: key}})
  end

  @spec execute_lua_request(%{:lua_request => binary(), optional(pid()) => any()}) :: any()
  def execute_lua_request(pid \\ __MODULE__, %{lua_request: lua_request}) do
    GenServer.call(pid, {:execute_lua_request, %{lua_request: lua_request}})
  end

  @impl GenServer
  def init(_opts) do
    {:ok, %{}}
  end

  @impl GenServer
  def handle_call({:push, %{database_name: database_name, key: key, value: value}}, _from, state) do
    case Map.fetch(state, database_name) do
      {:ok, database} ->
        updated_database = Map.put(database, key, value)
        updated_state = Map.put(state, database_name, updated_database)
        {:reply, {:ok, :new_data_added}, updated_state}

      :error ->
        updated_state = Map.put(state, database_name, Map.new(%{key => value}))
        {:reply, {:ok, :new_data_added}, updated_state}
    end
  end

  def handle_call({:get_data, %{database_name: database_name, key: key}}, _from, state) do
    with {:ok, database} <- Map.fetch(state, database_name),
         {:ok, value} <- Map.fetch(database, key) do
      {:reply, {:ok, value}, state}
    else
      :error -> {:reply, {:data_not_found, "The database or key do not exist"}, state}
    end
  end

  def handle_call({:delete_key, %{database_name: database_name, key: key}}, _from, state) do
    with {:ok, database} <- Map.fetch(state, database_name),
         {:ok, _value} <- Map.fetch(database, key) do
      updated_database = Map.delete(database, key)
      updated_state = Map.put(state, database_name, updated_database)
      {:reply, {:ok, :key_deleted}, updated_state}
    else
      :error -> {:reply, {:data_not_found, "The database or key do not exist"}, state}
    end
  end

  def handle_call({:delete_database, %{database_name: database_name}}, _from, state) do
    case Map.fetch(state, database_name) do
      {:ok, _database} ->
        updated_state = Map.delete(state, database_name)
        {:reply, {:ok, :database_deleted}, updated_state}

      :error ->
        {:reply, {:data_not_found, "The database does not exist"}, state}
    end
  end

  def handle_call({:execute_lua_request, %{lua_request: lua_request}}, _from, state) do
    luerl = Luerl.init()

    returned =
      Luerl.do(
        luerl,
        "return dofile('/Users/cassandre/Projects/application-build/cim/lib/cim/custom.lua')"
      )

    dbg(returned)
    dbg(lua_request)
    {ret, other} = Luerl.do(luerl, "printer('my_key')")
    # {ret, other} = Luerl.eval(luerl, lua_request)
    dbg("#{ret}")
    dbg("#{other}")
    {:reply, {:ok, "We're doing lua stuff"}, state}
  end
end

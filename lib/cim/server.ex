defmodule Cim.Server do
  use GenServer

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  def push(pid \\ __MODULE__, %{database_name: database_name, key: key, body: body}) do
    GenServer.cast(pid, {:push, %{database_name: database_name, key: key, value: body}})
  end

  def delete_key(pid \\ __MODULE__, %{database_name: database_name, key: key}) do
    GenServer.call(pid, {:delete_key, %{database_name: database_name, key: key}})
  end

  def delete_database(pid \\ __MODULE__, %{database_name: database_name}) do
    GenServer.call(pid, {:delete_database, %{database_name: database_name}})
  end

  def get(%{database_name: database_name, key: key}, pid \\ __MODULE__) do
    GenServer.call(pid, {:get, %{database_name: database_name, key: key}})
  end

  @impl GenServer
  def init(_opts) do
    {:ok, %{}}
  end

  @impl GenServer
  def handle_cast({:push, %{database_name: database_name, key: key, value: value}}, state) do
    case Map.fetch(state, database_name) do
      {:ok, database} ->
        updated_database = Map.put(database, key, value)
        updated_state = Map.put(state, database_name, updated_database)
        {:noreply, updated_state}

      :error ->
        updated_state = Map.put(state, database_name, Map.new(%{key => value}))
        {:noreply, updated_state}
    end
  end

  @impl GenServer
  def handle_call({:get, %{database_name: database_name, key: key}}, _from, state) do
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
      {:reply, {:ok, updated_state}, updated_state}
    else
      :error -> {:reply, {:data_not_found, "The database or key do not exist"}, state}
    end
  end

  def handle_call({:delete_database, %{database_name: database_name}}, _from, state) do
    case Map.fetch(state, database_name) do
      {:ok, _database} ->
        updated_state = Map.delete(state, database_name)
        {:reply, {:ok, updated_state}, updated_state}

      :error ->
        {:reply, {:data_not_found, "The database does not exist"}, state}
    end
  end
end

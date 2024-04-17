defmodule Cim.Server do
  use GenServer

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  def push(pid \\ __MODULE__, %{path: %{"database" => database, "key" => key}, body: body}) do
    GenServer.cast(pid, {:push, %{database: database, key: key, value: body}})
  end

  def delete(pid \\ __MODULE__, params) do
    GenServer.call(pid, {:delete, params})
  end

  def get(%{"database" => database, "key" => key}, pid \\ __MODULE__) do
    GenServer.call(pid, {:get, %{database: database, key: key}})
  end

  @impl GenServer
  def init(_opts) do
    {:ok, %{}}
  end

  @impl GenServer
  def handle_cast({:push, %{database: database_name, key: key, value: value}}, state) do
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
  def handle_call({:get, %{database: database_name, key: key}}, _from, state) do
    with {:ok, database} <- Map.fetch(state, database_name),
         {:ok, value} <- Map.fetch(database, key) do
      {:reply, {:ok, value}, state}
    else
      :error -> {:reply, {:data_not_found, "The database or key do not exist"}, state}
    end
  end

  def handle_call({:delete, %{"database" => database_name, "key" => key}}, _from, state) do
    with {:ok, database} <- Map.fetch(state, database_name),
         {:ok, _value} <- Map.fetch(database, key) do
      updated_database = Map.delete(database, key)
      updated_state = Map.put(state, database_name, updated_database)
      {:reply, {:ok, updated_state}, updated_state}
    else
      :error -> {:reply, {:data_not_found, "The database or key do not exist"}, state}
    end
  end

  def handle_call({:delete, %{"database" => database_name}}, _from, state) do
    case Map.fetch(state, database_name) do
      {:ok, _database} ->
        updated_state = Map.delete(state, database_name)
        {:reply, {:ok, updated_state}, updated_state}

      :error ->
        {:reply, {:data_not_found, "The database does not exist"}, state}
    end
  end
end

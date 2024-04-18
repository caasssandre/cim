defmodule Cim.Router do
  @moduledoc false
  use Plug.Router

  alias Cim.DataController

  plug(:match)
  plug(:dispatch)

  get "/:database/:key" do
    DataController.show(conn)
  end

  put "/:database/:key" do
    DataController.create(conn)
  end

  delete "/:database" do
    DataController.delete_database(conn)
  end

  delete "/:database/:key" do
    DataController.delete_key(conn)
  end

  post "/:database" do
    DataController.execute_lua_request(conn)
  end

  match _ do
    send_resp(conn, 404, "Oops!")
  end
end

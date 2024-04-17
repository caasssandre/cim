defmodule Cim.Router do
  use Plug.Router

  plug(:match)
  plug(:dispatch)

  get "/:database/:key" do
    Cim.DataController.show(conn)
  end

  put "/:database/:key" do
    Cim.DataController.create(conn)
  end

  delete "/:database" do
    Cim.DataController.delete(conn)
  end

  delete "/:database/:key" do
    Cim.DataController.delete(conn)
  end

  post "/:database" do
    send_resp(conn, 200, "Lua code")
  end

  match _ do
    send_resp(conn, 404, "Oops!")
  end
end

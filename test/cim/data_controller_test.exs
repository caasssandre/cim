defmodule Cim.DataControllerTest do
  use ExUnit.Case, async: true
  use Plug.Test

  alias Cim.Router
  alias Cim.DataController
  alias Cim.Server

  @opts Router.init([])

  describe "show/1" do
    # setup do
    #   pid = start_supervised!({Server, name: nil})
    #   [pid: pid]
    # end

    test "cannot find the key" do
      conn =
        :get
        |> conn("/db/k")
        |> Router.call(@opts)

      assert conn.state == :sent
      assert conn.status == 404
      assert conn.resp_body == "The database or key do not exist"
    end

    test "finds the key and returns 200" do
      # How do I add the value in memory here?

      conn =
        :get
        |> conn("/db/k")
        |> Router.call(@opts)

      assert conn.state == :sent
      assert conn.status == 200
      assert conn.resp_body == "hello"
    end
  end
end

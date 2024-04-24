defmodule Cim.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    Dotenv.load()

    children = [
      Cim.Datastore,
      {Plug.Cowboy, scheme: :http, plug: Cim.Router, options: [port: cowboy_port()]}
      # Starts a worker by calling: Cim.Worker.start_link(arg)
      # {Cim.Worker, arg}
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: Cim.Supervisor]
    Supervisor.start_link(children, opts)
  end

  defp cowboy_port, do: Application.get_env(:cim, :cowboy_port, 8080)
end

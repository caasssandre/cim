import Config

if System.get_env("COWBOY_PORT") do
  config :cim,
    cowboy_port: System.get_env("COWBOY_PORT") |> String.to_integer()
end

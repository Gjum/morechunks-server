use Mix.Config

listen_port_from_env =
  with port_str <- System.get_env("PORT"),
       {port, ""} <- :string.to_integer(port_str) do
    port
  else
    _ -> 12312
  end

config :morechunks,
  listen_ip: {127, 0, 0, 1},
  listen_port: listen_port_from_env

# You can configure for your application as:
#
#     config :morechunks, key: :value
#
# Or configure a 3rd-party app:
#
#     config :logger, level: :info
#

# It is also possible to import configuration files, relative to this
# directory. For example, you can emulate configuration per environment
# by uncommenting the line below and defining dev.exs, test.exs and such.
# Configuration from the imported file will override the ones defined
# here (which is why it is important to import them last).
#
#     import_config "#{Mix.env}.exs"

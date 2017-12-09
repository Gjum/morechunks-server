use Mix.Config

config :morechunks,
  max_chunks_per_second: 80,
  listen_ip: {0, 0, 0, 0},
  listen_port: 12312

config :logger,
  level: :info,
  backends: [
    :console,
    {LoggerFileBackend, :file_log}
  ]

config :logger, :console,
  metadata: [:module, :client]

config :logger, :file_log,
  path: "morechunks.log",
  metadata: [:module, :client]

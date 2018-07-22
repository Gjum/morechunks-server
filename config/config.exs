use Mix.Config

config :morechunks,
  max_chunks_per_second: 80,
  listen_ip: {0, 0, 0, 0},
  listen_port: 44444,
  allowed_versions: nil

config :logger,
  backends: [
    :console,
    {LoggerFileBackend, :file_log}
  ]

config :logger, :console,
  level: :info,
  metadata: [:client]

config :logger, :file_log,
  path: "morechunks.log",
  metadata: [:client]

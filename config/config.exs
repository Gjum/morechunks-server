use Mix.Config

config :morechunks,
  max_chunks_per_second: 80,
  listen_ip: {0, 0, 0, 0},
  listen_port: 12312

config :logger,
  backends: [
    :console,
    {LoggerFileBackend, :file_log}
  ]

config :logger, :file_log, path: "morechunks.log"

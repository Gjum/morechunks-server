use Mix.Config

config :morechunks,
  max_chunks_per_second: 80,
  listen_ip: {0, 0, 0, 0},
  listen_port: 12312,
  allowed_versions: [
    # beta-4
    "1.0.0-pre-git-980f072",
    # beta-3
    "1.0.0-pre-git-2b62537"
  ]

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

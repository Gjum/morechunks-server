use Mix.Config

config :morechunks,
  max_chunks_per_second: 80,
  listen_ip: {0, 0, 0, 0},
  listen_port: 12312

config :morechunks,
  ignored_metrics: [
    :chunk_loaded,
    :chunk_lookup_hit,
    :chunk_lookup_miss,
    :chunk_update,
    :sent_chunk,
    :user_contributed_chunk
  ]

config :logger,
  level: :info,
  backends: [
    :console,
    {LoggerFileBackend, :file_log}
  ]

config :logger, :file_log, path: "morechunks.log"

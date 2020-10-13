import Config

config :logger,
  level: String.to_atom(System.get_env("LOG_LEVEL") || "info"),
  handle_otp_reports: true,
  handle_sasl_reports: true

config :logger, :console,
  format: {PrettyConsoleLog, :format},
  metadata: [:pid, :context]

config :coda_validation,
  project_id: "o1labs-192920",
  region: "us-east1",
  cluster: "coda-infra-east",
  testnet: "regeneration"

if File.exists?("config/local.exs") do
  import_config "local.exs"
end

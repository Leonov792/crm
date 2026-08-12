# Конфигурация CRM Dashboard (Phoenix)
import Config

config :crm_dashboard, CrmWeb.Endpoint,
  url: [host: "localhost"],
  http: [port: 4000],
  server: true,
  live_view: [signing_salt: "crm_salt_2024"],
  secret_key_base: "REPLACE_WITH_SECRET_KEY_BASE"

config :crm_dashboard, :go_api,
  url: System.get_env("GO_API_URL") || "http://localhost:8080/api"

config :crm_dashboard, ecto_repos: [Crm.Repo]

config :crm_dashboard, Crm.Repo,
  database: "../crm_dashboard.db",
  journal_mode: :wal,
  pool_size: 5

config :crm_dashboard, :go_api,
  url: System.get_env("GO_API_URL") || "http://localhost:8080/api"

config :logger, level: :info

if config_env() == :prod do
  config :crm_dashboard, CrmWeb.Endpoint,
    url: [host: "localhost"],
    server: true
end

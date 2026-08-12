defmodule Crm.Repo do
  use Ecto.Repo,
    otp_app: :crm_dashboard,
    adapter: Ecto.Adapters.SQLite3
end

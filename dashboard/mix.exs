defmodule Crm.MixProject do
  @moduledoc """
  Гибридное ядро CRM — Elixir оркестратор + Rust NIF + Go API bridge.
  """

  use Mix.Project

  def project do
    [
      app: :crm_dashboard,
      version: "1.0.0",
      elixir: "~> 1.17",
      start_permanent: Mix.env() == :prod,
      aliases: aliases(),
      deps: deps(),
      rustler_crates: [crm_native: [path: "native/crm_native", mode: :release]]
    ]
  end

  def application do
    [
      mod: {Crm.Application, []},
      extra_applications: [:logger, :runtime_tools]
    ]
  end

  defp aliases do
    [
      "ecto.setup": ["ecto.create", "ecto.migrate"],
      "ecto.reset": ["ecto.drop", "ecto.setup"]
    ]
  end

  defp deps do
    [
      {:phoenix, "~> 1.7"},
      {:phoenix_live_view, "~> 0.20"},
      {:rustler, "~> 0.34"},
      {:gen_stage, "~> 1.2"},
      {:httpoison, "~> 2.2"},
      {:jason, "~> 1.4"},
      {:plug_cowboy, "~> 2.7"},
      {:ecto_sqlite3, "~> 0.17"},
      {:ecto_sql, "~> 3.11"},
      {:phoenix_pubsub, "~> 2.1"}
    ]
  end
end

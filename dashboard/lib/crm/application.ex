defmodule Crm.Application do
  @moduledoc """
  Supervisor приложения CRM Dashboard.
  Стратегия :one_for_one — падение одного процесса не убивает остальные.
  Перезапускает упавший процесс с задержкой 1 секунда.
  """

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      # Ecto Repo (SQLite)
      Crm.Repo,

      # Phoenix PubSub для реалтайм-событий
      {Phoenix.PubSub, name: Crm.PubSub},

      # HTTP-мост к Go CRM API (опрос каждые 5 секунд)
      {Crm.GoBridge, []},

      # GenStage пайплайн для импорта CSV через Rust NIF
      {Crm.ImportPipeline.Producer, []},
      {Crm.ImportPipeline.Consumer, []},

      # Phoenix endpoint с LiveView (:4000)
      CrmWeb.Endpoint
    ]

    opts = [
      strategy: :one_for_one,
      name: Crm.Supervisor,
      max_restarts: 5,
      max_seconds: 10
    ]

    Supervisor.start_link(children, opts)
  end
end

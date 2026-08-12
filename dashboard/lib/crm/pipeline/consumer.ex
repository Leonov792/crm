defmodule Crm.ImportPipeline.Consumer do
  @moduledoc """
  GenStage Consumer — обрабатывает события импорта CSV.
  Вызывает Rust NIF для парсинга и сохраняет результаты в Go CRM через API.
  """

  use GenStage
  require Logger

  def start_link(_) do
    GenStage.start_link(__MODULE__, :ok, name: __MODULE__)
  end

  @impl true
  def init(:ok) do
    {:consumer, :ok, subscribe_to: [Crm.ImportPipeline.Producer]}
  end

  @impl true
  def handle_events(events, _from, state) do
    Enum.each(events, &process_event/1)
    {:noreply, [], state}
  end

  defp process_event({:import_csv, path}) do
    Logger.info("[ImportPipeline] Processing CSV: #{path}")

    # Шаг 1: парсим CSV через Rust NIF (Dirty Scheduler)
    case Crm.NativeBridge.parse_csv(path) do
      {:ok, records} ->
        Logger.info("[ImportPipeline] Parsed #{length(records)} records")
        # Шаг 2: импортируем каждый лид в Go CRM через API
        Enum.each(records, fn record ->
          import_contact(record)
        end)

      {:error, reason} ->
        Logger.error("[ImportPipeline] CSV parse failed: #{reason}")
    end
  end

  defp import_contact(%{name: name} = record) do
    body = Jason.encode!(%{
      name: name || "",
      phone: Map.get(record, :phone, ""),
      email: Map.get(record, :email, ""),
      company: Map.get(record, :company, "")
    })

    go_api = Application.get_env(:crm_dashboard, :go_api, "http://localhost:8080/api")

    case HTTPoison.post("#{go_api}/contacts", body, [{"Content-Type", "application/json"}]) do
      {:ok, %{status_code: 200}} -> :ok
      {:error, reason} -> Logger.warning("[ImportPipeline] Failed to import contact: #{inspect(reason)}")
    end
  end

  defp import_contact(_), do: :skip
end

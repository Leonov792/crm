defmodule Crm.GoBridge do
  @moduledoc """
  HTTP-клиент к существующему Go CRM API (:8080).
  Синхронизирует данные между LiveView дашбордом и Go-частью.

  Работает как GenServer с периодическим опросом (5 секунд).
  """

  use GenServer

  defp go_api do
    Application.get_env(:crm_dashboard, :go_api, "http://localhost:8080/api")
  end

  # ======== Публичный API ========

  def start_link(_) do
    GenServer.start_link(__MODULE__, %{tasks: [], contacts: []}, name: __MODULE__)
  end

  @doc "Возвращает текущие задачи из кеша GenServer"
  def get_tasks do
    GenServer.call(__MODULE__, :get_tasks)
  end

  @doc "Возвращает текущие контакты из кеша GenServer"
  def get_contacts do
    GenServer.call(__MODULE__, :get_contacts)
  end

  @doc "Получить задачи напрямую из Go CRM (без кеша)"
  def fetch_tasks do
    get_json("#{go_api()}/tasks")
  end

  @doc "Получить контакты напрямую из Go CRM (без кеша)"
  def fetch_contacts do
    get_json("#{go_api()}/contacts")
  end

  # ======== GenServer Callbacks ========

  @impl true
  def init(state) do
    schedule_poll()
    {:ok, state}
  end

  @impl true
  def handle_call(:get_tasks, _from, state) do
    {:reply, {:ok, state.tasks}, state}
  end

  @impl true
  def handle_call(:get_contacts, _from, state) do
    {:reply, {:ok, state.contacts}, state}
  end

  @impl true
  def handle_info(:poll, state) do
    new_state = state
      |> update_tasks()
      |> update_contacts()

    schedule_poll()
    {:noreply, new_state}
  end

  # ======== Приватные функции ========

  defp update_tasks(state) do
    case get_json("#{go_api()}/tasks") do
      {:ok, tasks} when is_list(tasks) -> %{state | tasks: tasks}
      _ -> state
    end
  end

  defp update_contacts(state) do
    case get_json("#{go_api()}/contacts") do
      {:ok, contacts} when is_list(contacts) -> %{state | contacts: contacts}
      _ -> state
    end
  end

  defp schedule_poll do
    Process.send_after(self(), :poll, 5_000)
  end

  defp get_json(url) do
    case HTTPoison.get(url) do
      {:ok, %HTTPoison.Response{status_code: 200, body: body}} ->
        {:ok, Jason.decode!(body)}
      {:error, %HTTPoison.Error{reason: reason}} ->
        {:error, reason}
      _ ->
        {:error, :unknown}
    end
  end
end

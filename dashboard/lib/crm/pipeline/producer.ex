defmodule Crm.ImportPipeline.Producer do
  @moduledoc """
  GenStage Producer — генерирует события импорта CSV.
  Принимает path к CSV-файлу, передаёт в Consumer для парсинга через Rust NIF.
  """

  use GenStage

  def start_link(_) do
    GenStage.start_link(__MODULE__, :ok, name: __MODULE__)
  end

  @doc "Отправить CSV-файл на импорт"
  def import_csv(path) when is_binary(path) do
    GenStage.call(__MODULE__, {:import, path})
  end

  @impl true
  def init(:ok) do
    {:producer, %{demand: 0, queue: :queue.new()}}
  end

  @impl true
  def handle_demand(demand, state) do
    {events, queue} = drain_queue(demand, state.queue)
    {:noreply, events, %{state | demand: demand - length(events), queue: queue}}
  end

  @impl true
  def handle_call({:import, path}, _from, state) do
    queue = :queue.in({:import_csv, path}, state.queue)
    events = if state.demand > 0, do: drain_events(state.demand, queue), else: []
    {:reply, {:ok, :queued}, events, %{state | queue: queue}}
  end

  defp drain_queue(demand, queue) when demand > 0 do
    drain_events(demand, queue)
  end

  defp drain_events(0, queue), do: {[], queue}
  defp drain_events(n, queue) do
    case :queue.out(queue) do
      {{:value, event}, new_queue} ->
        {rest, final_queue} = drain_events(n - 1, new_queue)
        {[event | rest], final_queue}
      {:empty, _} ->
        {[], queue}
    end
  end
end

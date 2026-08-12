defmodule CrmWeb.DashboardLive do
  @moduledoc """
  Реактивный дашборд CRM на Phoenix LiveView.
  - Kanban-доска с drag-n-drop через phx-click
  - Реалтайм-метрики (сумма сделок, конверсия, лиды сегодня)
  - GenStage конвейер импорта CSV с прогресс-баром
  - Отказоустойчивость при обрыве связи с Go CRM
  - Вызов Rust NIF для скоринга и расчёта воронки
  """

  use Phoenix.LiveView
  import Ecto.Query, only: [from: 2]
  import Decimal, only: [compare: 2, round: 2, to_string: 1, new: 1, add: 2]
  require Logger

  alias Crm.{Repo, Deal, GoBridge, NativeBridge}
  alias Crm.ImportPipeline.Producer

  @stages Deal.stages()
  @poll_interval 5000
  @metrics_interval 15000

  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket) do
      :timer.send_interval(@poll_interval, self(), :poll_go)
      :timer.send_interval(@metrics_interval, self(), :recalc_metrics)
      Phoenix.PubSub.subscribe(Crm.PubSub, "deals")
      Phoenix.PubSub.subscribe(Crm.PubSub, "import_progress")
    end

    deals = Repo.all(from d in Deal, order_by: [asc: d.position])
    metrics = calc_metrics(deals)

    {:ok,
     assign(socket,
       page: "kanban",
       deals: deals,
       metrics: metrics,
       stages: @stages,
       go_online: true,
       import_progress: 0,
       import_total: 0,
       import_status: nil,
       show_form: false,
       form_title: "",
       form_amount: "",
       form_contact: "",
       form_source: "go_crm"
     )}
  end

  # ========================================================================
  # POLLING & METRICS
  # ========================================================================

  @impl true
  def handle_info(:poll_go, socket) do
    online = case GoBridge.fetch_tasks() do
      {:ok, _} -> true
      _ -> false
    end
    {:noreply, assign(socket, go_online: online)}
  end

  @impl true
  def handle_info(:recalc_metrics, socket) do
    deals = Repo.all(from d in Deal, order_by: [asc: d.position])
    metrics = calc_metrics(deals)

    # Периодический вызов Rust NIF для расчёта воронки
    _report = case Jason.encode(%{tasks_count: length(deals), contacts_count: length(deals)}) do
      {:ok, json} -> NativeBridge.generate_report(json)
      _ -> {:error, :json_fail}
    end

    {:noreply, assign(socket, deals: deals, metrics: metrics)}
  end

  # ========================================================================
  # PUBSUB — realtime updates from other processes
  # ========================================================================

  @impl true
  def handle_info({:deal_updated, deal}, socket) do
    deals = update_deal_in_list(socket.assigns.deals, deal)
    {:noreply, assign(socket, deals: deals, metrics: calc_metrics(deals))}
  end

  @impl true
  def handle_info({:import_progress, progress, total}, socket) do
    pct = if total > 0, do: round(progress / total * 100), else: 0
    {:noreply, assign(socket, import_progress: pct, import_total: total, import_status: "Импорт: #{progress}/#{total}" )}
  end

  # ========================================================================
  # KANBAN EVENTS
  # ========================================================================

  @impl true
  def handle_event("move_deal", %{"deal_id" => deal_id, "stage" => new_stage}, socket) do
    deal = Repo.get!(Deal, deal_id)
    changeset = Deal.changeset(deal, %{stage: new_stage})
    {:ok, updated} = Repo.update(changeset)

    Phoenix.PubSub.broadcast!(Crm.PubSub, "deals", {:deal_updated, updated})
    {:noreply, socket}
  end

  @impl true
  def handle_event("create_deal", params, socket) do
    amount = case Decimal.parse(params["amount"] || "0") do
      {d, _} -> d
      _ -> Decimal.new(0)
    end

    changeset = Deal.changeset(%Deal{}, %{
      title: params["title"] || "Новый лид",
      amount: amount,
      contact_name: params["contact"] || "",
      source: params["source"] || "go_crm",
      stage: "lead",
      tags: parse_tags(params["title"] || "")
    })

    case Repo.insert(changeset) do
      {:ok, deal} ->
        Phoenix.PubSub.broadcast!(Crm.PubSub, "deals", {:deal_updated, deal})
        {:noreply,
         assign(socket,
           show_form: false,
           deals: socket.assigns.deals ++ [deal],
           metrics: calc_metrics(socket.assigns.deals ++ [deal])
         )}

      {:error, cs} ->
        {:noreply, put_flash(socket, :error, "Ошибка: #{inspect(cs.errors)}")}
    end
  end

  @impl true
  def handle_event("delete_deal", %{"deal_id" => deal_id}, socket) do
    deal = Repo.get!(Deal, deal_id)
    Repo.delete!(deal)
    deals = Enum.reject(socket.assigns.deals, &(&1.id == deal.id))
    Phoenix.PubSub.broadcast!(Crm.PubSub, "deals", {:deal_updated, nil})
    {:noreply, assign(socket, deals: deals, metrics: calc_metrics(deals))}
  end

  @impl true
  def handle_event("toggle_form", _, socket) do
    {:noreply, assign(socket, show_form: !socket.assigns.show_form)}
  end

  @impl true
  def handle_event("switch_page", %{"page" => page}, socket) do
    {:noreply, assign(socket, page: page)}
  end

  @impl true
  def handle_event("start_import", %{"path" => path}, socket) do
    Producer.import_csv(path)
    {:noreply,
     assign(socket,
       import_progress: 0,
       import_total: 0,
       import_status: "Запущен импорт #{path}..."
     )}
  end

  # ========================================================================
  # HELPERS
  # ========================================================================

  defp calc_metrics(deals) do
    total_sum = deals |> Enum.reduce(Decimal.new(0), fn d, acc ->
      Decimal.add(acc, d.amount || Decimal.new(0))
    end)
    won = Enum.count(deals, &(&1.stage == "closed_won"))
    lost = Enum.count(deals, &(&1.stage == "closed_lost"))
    total = length(deals)
    today = Enum.count(deals, fn d ->
      d.inserted_at && NaiveDateTime.diff(NaiveDateTime.utc_now(), d.inserted_at, :hour) < 24
    end)
    conversion = if total > 0, do: round(won / total * 100), else: 0

    %{
      total: total,
      total_sum: total_sum,
      won: won,
      lost: lost,
      today: today,
      conversion: conversion,
      pipeline_value: total_sum |> Decimal.to_float() |> format_money()
    }
  end

  defp update_deal_in_list(deals, updated) when is_nil(updated), do: deals
  defp update_deal_in_list(deals, updated) do
    Enum.map(deals, fn d -> if d.id == updated.id, do: updated, else: d end)
  end

  defp parse_tags(title) when is_binary(title) do
    title
    |> String.downcase()
    |> String.split(~r/[\s,]+/, trim: true)
    |> Enum.filter(&(String.length(&1) > 1))
    |> Enum.take(3)
  end
  defp parse_tags(_), do: []

  defp format_money(nil), do: "0"
  defp format_money(n) when is_float(n), do: :erlang.float_to_binary(n, decimals: 0) <> " ₽"
  defp format_money(%Decimal{} = d), do: d |> Decimal.round(0) |> Decimal.to_string() |> Kernel.<>(" ₽")

  # ========================================================================
  # RENDER — Full LiveView Template
  # ========================================================================

  @impl true
  def render(assigns) do
    ~H"""
    <div class="min-h-screen bg-[#0B0E11] text-[#EAECEF] font-sans">
      <%!-- Header --%>
      <header class="bg-[#1E2329] border-b border-[#2B3139] px-6 py-4 flex items-center justify-between sticky top-0 z-50">
        <div class="flex items-center gap-4">
          <h1 class="text-xl font-bold text-[#F0B90B] tracking-tight">CRM Dashboard</h1>
          <span class="text-xs text-[#848E9C]">LiveView • Real-time</span>
        </div>
        <div class="flex items-center gap-3">
          <%!-- Go CRM status indicator --%>
          <div class={"flex items-center gap-2 px-3 py-1.5 rounded-full text-xs font-medium " <> if @go_online, do: "bg-[#0ECB81]/10 text-[#0ECB81]", else: "bg-[#F6465D]/10 text-[#F6465D]" }>
            <span class={"w-2 h-2 rounded-full " <> if @go_online, do: "bg-[#0ECB81] animate-pulse", else: "bg-[#F6465D]"}></span>
            <%= if @go_online, do: "Go CRM Online", else: "Go CRM Offline" %>
          </div>
          <%!-- Tabs --%>
          <div class="flex gap-1 bg-[#0B0E11] rounded-lg p-1">
            <button phx-click="switch_page" phx-value-page="kanban"
              class={"px-4 py-1.5 rounded-md text-sm font-medium transition " <> if @page == "kanban", do: "bg-[#F0B90B] text-black", else: "text-[#848E9C] hover:text-white"}>
              Kanban
            </button>
            <button phx-click="switch_page" phx-value-page="import"
              class={"px-4 py-1.5 rounded-md text-sm font-medium transition " <> if @page == "import", do: "bg-[#F0B90B] text-black", else: "text-[#848E9C] hover:text-white"}>
              Import
            </button>
          </div>
        </div>
      </header>

      <%!-- Go CRM Offline Overlay --%>
      <%= if !@go_online do %>
        <div class="bg-[#F6465D]/10 border-b border-[#F6465D]/30 px-6 py-3 text-center text-sm text-[#F6465D] animate-pulse">
          Соединение с локальным ядром CRM восстанавливается... Проверьте Go сервер на :8080
        </div>
      <% end %>

      <%!-- Metrics Cards --%>
      <div class="px-6 py-4">
        <div class="grid grid-cols-2 lg:grid-cols-5 gap-3">
          <div class="bg-[#1E2329] border border-[#2B3139] rounded-xl p-4 hover:border-[#3A414A] transition">
            <div class="text-xs text-[#848E9C] uppercase tracking-wider">Всего сделок</div>
            <div class="text-2xl font-bold mt-1"><%= @metrics.total %></div>
          </div>
          <div class="bg-[#1E2329] border border-[#2B3139] rounded-xl p-4 hover:border-[#3A414A] transition">
            <div class="text-xs text-[#848E9C] uppercase tracking-wider">Сумма воронки</div>
            <div class="text-2xl font-bold mt-1 text-[#0ECB81]"><%= @metrics.pipeline_value %></div>
          </div>
          <div class="bg-[#1E2329] border border-[#2B3139] rounded-xl p-4 hover:border-[#3A414A] transition">
            <div class="text-xs text-[#848E9C] uppercase tracking-wider">Конверсия</div>
            <div class="text-2xl font-bold mt-1 text-[#3EB2FD]"><%= @metrics.conversion %>%</div>
          </div>
          <div class="bg-[#1E2329] border border-[#2B3139] rounded-xl p-4 hover:border-[#3A414A] transition">
            <div class="text-xs text-[#848E9C] uppercase tracking-wider">Выиграно</div>
            <div class="text-2xl font-bold mt-1 text-[#0ECB81]"><%= @metrics.won %></div>
          </div>
          <div class="bg-[#1E2329] border border-[#2B3139] rounded-xl p-4 hover:border-[#3A414A] transition">
            <div class="text-xs text-[#848E9C] uppercase tracking-wider">Лидов сегодня</div>
            <div class="text-2xl font-bold mt-1 text-[#F0B90B]"><%= @metrics.today %></div>
          </div>
        </div>
      </div>

      <%!-- PAGE: KANBAN --%>
      <%= if @page == "kanban" do %>
        <div class="px-6 pb-6">
          <%!-- Add Deal Button --%>
          <div class="flex items-center justify-between mb-4">
            <h2 class="text-lg font-semibold">Воронка сделок</h2>
            <button phx-click="toggle_form"
              class="px-4 py-2 bg-[#F0B90B] hover:bg-[#f5c92a] active:scale-95 text-black text-sm font-semibold rounded-lg transition">
              + Новый лид
            </button>
          </div>

          <%!-- Create Deal Form --%>
          <%= if @show_form do %>
            <div class="bg-[#1E2329] border border-[#2B3139] rounded-xl p-4 mb-4 animate-[fadeIn_0.2s_ease]">
              <form phx-submit="create_deal" class="grid grid-cols-2 lg:grid-cols-4 gap-3">
                <input type="text" name="title" placeholder="Название *" required
                  class="bg-[#0B0E11] border border-[#2B3139] focus:border-[#F0B90B] rounded-lg px-3 py-2 text-sm outline-none transition" />
                <input type="text" name="amount" placeholder="Сумма"
                  class="bg-[#0B0E11] border border-[#2B3139] focus:border-[#F0B90B] rounded-lg px-3 py-2 text-sm outline-none transition" />
                <input type="text" name="contact" placeholder="Контакт"
                  class="bg-[#0B0E11] border border-[#2B3139] focus:border-[#F0B90B] rounded-lg px-3 py-2 text-sm outline-none transition" />
                <select name="source"
                  class="bg-[#0B0E11] border border-[#2B3139] focus:border-[#F0B90B] rounded-lg px-3 py-2 text-sm outline-none transition">
                  <option value="go_crm">Go CRM</option>
                  <option value="telegram_bot">Telegram Bot</option>
                  <option value="csv_import">CSV Import</option>
                </select>
                <button type="submit"
                  class="col-span-full py-2 bg-[#F0B90B] hover:bg-[#f5c92a] active:scale-95 text-black font-semibold rounded-lg transition text-sm">
                  Создать
                </button>
              </form>
            </div>
          <% end %>

          <%!-- Kanban Board --%>
          <div class="grid grid-cols-2 lg:grid-cols-6 gap-3 overflow-x-auto">
            <%= for stage <- @stages do %>
              <div class={"bg-[#1E2329] border-t-2 rounded-xl p-3 min-h-[150px] " <> Deal.stage_color(stage)}>
                <div class="flex items-center justify-between mb-3">
                  <h3 class="text-xs font-semibold text-[#848E9C] uppercase tracking-wider">
                    <%= Deal.stage_label(stage) %>
                  </h3>
                  <span class="text-xs text-[#5E6673] font-mono">
                    <%= Enum.count(@deals, &(&1.stage == stage)) %>
                  </span>
                </div>

                <div class="space-y-2" id={"stage-#{stage}"} phx-drop="move_deal">
                  <%= for deal <- Enum.filter(@deals, &(&1.stage == stage)) do %>
                    <div class="bg-[#0B0E11] border border-[#2B3139] hover:border-[#3A414A] rounded-lg p-3 cursor-pointer
                      hover:shadow-lg active:scale-[0.98] transition group"
                      id={"deal-#{deal.id}"} draggable="true"
                      phx-click="move_deal" phx-value-deal_id={deal.id} phx-value-stage={next_stage(deal.stage)}>
                      <%!-- Title + Delete --%>
                      <div class="flex items-start justify-between">
                        <div class="text-sm font-medium leading-snug flex-1 mr-2"><%= deal.title %></div>
                        <button phx-click="delete_deal" phx-value-deal_id={deal.id}
                          class="opacity-0 group-hover:opacity-100 text-[#F6465D] hover:text-red-400 transition text-xs mt-0.5 flex-shrink-0"
                          onclick="event.stopPropagation()">
                          ×
                        </button>
                      </div>

                      <%!-- Amount --%>
                      <%= if deal.amount do %>
                        <% amt = Decimal.compare(deal.amount, Decimal.new(0)) %>
                        <%= if amt == :gt do %>
                          <div class="text-xs font-mono text-[#0ECB81] mt-1">
                            <%= deal.amount |> Decimal.round(0) |> Decimal.to_string() %> RUB
                          </div>
                        <% end %>
                      <% end %>

                      <%!-- Contact --%>
                      <%= if deal.contact_name && deal.contact_name != "" do %>
                        <div class="text-xs text-[#5E6673] mt-1 truncate"><%= deal.contact_name %></div>
                      <% end %>

                      <%!-- Tags + Source --%>
                      <div class="flex flex-wrap gap-1 mt-2">
                        <span class={"px-1.5 py-0.5 rounded text-[10px] font-medium " <> source_badge(deal.source)}>
                          <%= deal.source %>
                        </span>
                        <%= for tag <- (deal.tags || []) |> Enum.take(2) do %>
                          <span class="px-1.5 py-0.5 rounded text-[10px] bg-[#2B3139] text-[#848E9C]">
                            #<%= tag %>
                          </span>
                        <% end %>
                      </div>

                      <%!-- Priority dot --%>
                      <%= if deal.priority == "high" do %>
                        <div class="w-2 h-2 rounded-full bg-[#F6465D] mt-2"></div>
                      <% end %>
                    </div>
                  <% end %>
                </div>
              </div>
            <% end %>
          </div>
        </div>
      <% end %>

      <%!-- PAGE: IMPORT --%>
      <%= if @page == "import" do %>
        <div class="px-6 pb-6 max-w-2xl">
          <h2 class="text-lg font-semibold mb-4">Импорт CSV через Rust NIF + GenStage</h2>

          <%!-- Import Form --%>
          <div class="bg-[#1E2329] border border-[#2B3139] rounded-xl p-4 mb-4">
            <form phx-submit="start_import" class="flex gap-3">
              <input type="text" name="path" placeholder="Путь к CSV-файлу (напр. /data/leads.csv)" required
                class="flex-1 bg-[#0B0E11] border border-[#2B3139] focus:border-[#F0B90B] rounded-lg px-3 py-2 text-sm outline-none transition" />
              <button type="submit"
                class="px-6 py-2 bg-[#F0B90B] hover:bg-[#f5c92a] active:scale-95 text-black font-semibold rounded-lg transition text-sm whitespace-nowrap">
                Запустить импорт
              </button>
            </form>
            <div class="text-xs text-[#5E6673] mt-3">
              CSV парсится через Rust NIF (Dirty Scheduler). GenStage распределяет лиды по базе данных.
            </div>
          </div>

          <%!-- Progress Bar --%>
          <%= if @import_total > 0 do %>
            <div class="bg-[#1E2329] border border-[#2B3139] rounded-xl p-4">
              <div class="flex justify-between text-sm mb-2">
                <span class="text-[#848E9C]"><%= @import_status %></span>
                <span class="font-mono text-[#F0B90B]"><%= @import_progress %>%</span>
              </div>
              <div class="h-2 bg-[#0B0E11] rounded-full overflow-hidden">
                <div class="h-full bg-gradient-to-r from-[#F0B90B] to-[#0ECB81] rounded-full transition-all duration-500"
                  style={"width: #{@import_progress}%"}></div>
              </div>
              <div class="text-xs text-[#5E6673] mt-2">
                Rust NIF обрабатывает файл, GenStage Consumer сохраняет лиды в БД.
              </div>
            </div>
          <% end %>

          <%!-- Info box --%>
          <div class="bg-[#1E2329] border border-[#2B3139] rounded-xl p-4 mt-4">
            <h3 class="text-sm font-semibold mb-2">Как работает конвейер импорта</h3>
            <div class="space-y-2 text-sm text-[#848E9C]">
              <div class="flex gap-3 items-start">
                <span class="w-6 h-6 rounded-full bg-[#F0B90B]/20 text-[#F0B90B] flex items-center justify-center text-xs font-bold flex-shrink-0">1</span>
                <span><strong>Producer (GenStage):</strong> Принимает путь к CSV, ставит в очередь.</span>
              </div>
              <div class="flex gap-3 items-start">
                <span class="w-6 h-6 rounded-full bg-[#F0B90B]/20 text-[#F0B90B] flex items-center justify-center text-xs font-bold flex-shrink-0">2</span>
                <span><strong>Consumer → Rust NIF:</strong> parse_csv(path) через Dirty Scheduler BEAM.</span>
              </div>
              <div class="flex gap-3 items-start">
                <span class="w-6 h-6 rounded-full bg-[#F0B90B]/20 text-[#F0B90B] flex items-center justify-center text-xs font-bold flex-shrink-0">3</span>
                <span><strong>Consumer → Go CRM:</strong> HTTP POST каждого лида в Go CRM API :8080.</span>
              </div>
              <div class="flex gap-3 items-start">
                <span class="w-6 h-6 rounded-full bg-[#F0B90B]/20 text-[#F0B90B] flex items-center justify-center text-xs font-bold flex-shrink-0">4</span>
                <span><strong>LiveView Update:</strong> PubSub broadcast → прогресс-бар.</span>
              </div>
            </div>
          </div>
        </div>
      <% end %>

    </div>
    """
  end

  # Kanban: клик на карточку двигает её вправо по воронке
  defp next_stage(stage) do
    idx = Enum.find_index(@stages, &(&1 == stage)) || 0
    next_idx = min(idx + 1, length(@stages) - 1)
    Enum.at(@stages, next_idx)
  end

  defp source_badge("telegram_bot"), do: "bg-[#3EB2FD]/15 text-[#3EB2FD]"
  defp source_badge("csv_import"), do: "bg-[#F0B90B]/15 text-[#F0B90B]"
  defp source_badge("go_crm"), do: "bg-[#0ECB81]/15 text-[#0ECB81]"
  defp source_badge(_), do: "bg-[#2B3139] text-[#848E9C]"
end

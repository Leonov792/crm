defmodule Crm.Deal do
  @moduledoc """
  Схема сделки/лида для Kanban-доски.
  Поддерживает drag-n-drop между колонками через PubSub.
  """

  use Ecto.Schema
  import Ecto.Changeset

  @stages ~w(lead contact_meeting proposal negotiation closed_won closed_lost)

  schema "deals" do
    field :title, :string
    field :amount, :decimal, default: 0
    field :contact_name, :string
    field :contact_phone, :string
    field :source, :string, default: "go_crm"   # go_crm | telegram_bot | csv_import
    field :stage, :string, default: "lead"
    field :priority, :string, default: "medium"
    field :tags, {:array, :string}, default: []
    field :position, :integer, default: 0

    timestamps()
  end

  @doc "Стадии воронки с русскими названиями"
  def stages, do: @stages

  def stage_label("lead"), do: "Лиды"
  def stage_label("contact_meeting"), do: "Контакт"
  def stage_label("proposal"), do: "КП"
  def stage_label("negotiation"), do: "Переговоры"
  def stage_label("closed_won"), do: "Закрыто"
  def stage_label("closed_lost"), do: "Проиграно"
  def stage_label(s), do: s |> to_string |> String.capitalize()

  @doc "Цвета стадий для Tailwind"
  def stage_color("lead"), do: "border-gray-500"
  def stage_color("contact_meeting"), do: "border-blue-500"
  def stage_color("proposal"), do: "border-yellow-500"
  def stage_color("negotiation"), do: "border-purple-500"
  def stage_color("closed_won"), do: "border-green-500"
  def stage_color("closed_lost"), do: "border-red-500"
  def stage_color(_), do: "border-gray-600"

  @doc "Бейджи стадий для отображения"
  def stage_badge_color("lead"), do: "bg-gray-700 text-gray-300"
  def stage_badge_color("contact_meeting"), do: "bg-blue-500/20 text-blue-400"
  def stage_badge_color("proposal"), do: "bg-yellow-500/20 text-yellow-400"
  def stage_badge_color("negotiation"), do: "bg-purple-500/20 text-purple-400"
  def stage_badge_color("closed_won"), do: "bg-green-500/20 text-green-400"
  def stage_badge_color("closed_lost"), do: "bg-red-500/20 text-red-400"
  def stage_badge_color(_), do: "bg-gray-700 text-gray-300"

  def changeset(deal, attrs) do
    deal
    |> cast(attrs, [:title, :amount, :contact_name, :contact_phone, :source, :stage, :priority, :tags, :position])
    |> validate_required([:title])
    |> validate_inclusion(:stage, @stages)
  end
end

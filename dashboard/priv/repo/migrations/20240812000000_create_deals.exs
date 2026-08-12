defmodule Crm.Repo.Migrations.CreateDeals do
  use Ecto.Migration

  def change do
    create table(:deals) do
      add :title, :string, null: false
      add :amount, :decimal, default: 0
      add :contact_name, :string
      add :contact_phone, :string
      add :source, :string, default: "go_crm"
      add :stage, :string, default: "lead"
      add :priority, :string, default: "medium"
      add :tags, {:array, :string}, default: []
      add :position, :integer, default: 0

      timestamps()
    end

    create index(:deals, [:stage])
    create index(:deals, [:source])
    create index(:deals, [:inserted_at])
  end
end

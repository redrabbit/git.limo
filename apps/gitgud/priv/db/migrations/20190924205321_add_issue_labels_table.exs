defmodule GitGud.DB.Migrations.AddIssueLabelsTable do
  use Ecto.Migration

  def change do
    create table("issue_labels") do
      add :repo_id, references("repositories", on_delete: :delete_all)
      add :name, :string, null: false
      add :description, :string
      add :color, :string, size: 6, null: false
      timestamps()
    end

    create unique_index("issue_labels", [:repo_id, :name])

    create table("issues_labels", primary_key: false) do
      add :issue_id, references("issues", on_delete: :delete_all), null: false
      add :label_id, references("issue_labels", on_delete: :delete_all), null: false
    end
  end
end

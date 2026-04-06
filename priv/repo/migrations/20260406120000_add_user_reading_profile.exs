defmodule BibleReader.Repo.Migrations.AddUserReadingProfile do
  use Ecto.Migration

  def change do
    alter table(:users) do
      add :timezone, :string, null: false, default: "Etc/UTC"
      add :show_apocrypha, :boolean, null: false, default: false
    end
  end
end

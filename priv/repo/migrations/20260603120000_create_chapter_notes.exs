defmodule BibleReader.Repo.Migrations.CreateChapterNotes do
  use Ecto.Migration

  def change do
    create table(:chapter_notes) do
      add :user_id, references(:users, on_delete: :delete_all), null: false
      add :chapter_id, references(:chapters, on_delete: :delete_all), null: false
      add :body, :text, null: false, default: ""

      timestamps(type: :utc_datetime)
    end

    create unique_index(:chapter_notes, [:user_id, :chapter_id])
    create index(:chapter_notes, [:user_id])
  end
end

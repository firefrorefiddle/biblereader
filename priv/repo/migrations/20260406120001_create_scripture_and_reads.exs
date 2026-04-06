defmodule BibleReader.Repo.Migrations.CreateScriptureAndReads do
  use Ecto.Migration

  def change do
    create table(:books) do
      add :code, :string, null: false
      add :name, :string, null: false
      add :sort_order, :integer, null: false
      add :testament, :string, null: false
      add :in_protestant_canon, :boolean, null: false, default: false
      add :in_apocrypha, :boolean, null: false, default: false
    end

    create unique_index(:books, [:code])

    create table(:chapters) do
      add :book_id, references(:books, on_delete: :delete_all), null: false
      add :chapter_number, :integer, null: false
    end

    create unique_index(:chapters, [:book_id, :chapter_number])

    create table(:chapter_reads) do
      add :user_id, references(:users, on_delete: :delete_all), null: false
      add :chapter_id, references(:chapters, on_delete: :delete_all), null: false
      add :read_at, :utc_datetime, null: false
    end

    create index(:chapter_reads, [:user_id])
    create index(:chapter_reads, [:chapter_id])
    create index(:chapter_reads, [:user_id, :read_at])
  end
end

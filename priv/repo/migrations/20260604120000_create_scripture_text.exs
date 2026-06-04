defmodule BibleReader.Repo.Migrations.CreateScriptureText do
  use Ecto.Migration

  def change do
    create table(:bible_translations) do
      add :code, :string, null: false
      add :name, :string, null: false
      add :language, :string, null: false
      add :source_format, :string, null: false
      add :license, :string
      add :copyright_notice, :text
      add :source_path, :string

      timestamps(type: :utc_datetime)
    end

    create unique_index(:bible_translations, [:code])

    create table(:chapter_documents) do
      add :translation_id, references(:bible_translations, on_delete: :delete_all), null: false
      add :chapter_id, references(:chapters, on_delete: :delete_all), null: false
      add :blocks_json, {:array, :map}, null: false, default: []

      timestamps(type: :utc_datetime)
    end

    create unique_index(:chapter_documents, [:translation_id, :chapter_id])

    create table(:bible_verses) do
      add :translation_id, references(:bible_translations, on_delete: :delete_all), null: false
      add :chapter_id, references(:chapters, on_delete: :delete_all), null: false
      add :verse_number, :integer, null: false
      add :plain_text, :text, null: false, default: ""
      add :content_json, {:array, :map}, null: false, default: []

      timestamps(type: :utc_datetime)
    end

    create unique_index(:bible_verses, [:translation_id, :chapter_id, :verse_number])
    create index(:bible_verses, [:chapter_id])

    create table(:bible_footnotes) do
      add :verse_id, references(:bible_verses, on_delete: :delete_all), null: false
      add :marker, :string, null: false, default: ""
      add :ref_id, :string, null: false
      add :body, :text, null: false, default: ""
      add :position, :integer, null: false, default: 0
      add :display_number, :integer, null: false, default: 1

      timestamps(type: :utc_datetime)
    end

    create index(:bible_footnotes, [:verse_id])
  end
end

defmodule BibleReader.ScriptureText do
  @moduledoc """
  Licensed Bible **text** for reading: translations, chapter documents, verse index,
  and footnotes. Distinct from the read-only **Scripture** catalog (books/chapters).

  Text is imported from USFM (or other formats) into normalized JSON; the app reads
  from the database, not raw USFM at runtime.
  """

  import Ecto.Query

  alias BibleReader.Repo
  alias BibleReader.ScriptureText.{ChapterDocument, Footnote, Translation, Verse}

  @default_translation_code "deuelbbk"

  @doc """
  Returns the default translation row, or `nil` if not imported yet.
  """
  def get_default_translation do
    Repo.get_by(Translation, code: @default_translation_code)
  end

  @doc """
  Returns a translation by stable code, or `nil`.
  """
  def get_translation_by_code(code) when is_binary(code) do
    Repo.get_by(Translation, code: code)
  end

  @doc """
  Chapter document blocks for rendering, or `nil`.
  """
  def get_chapter_document(%Translation{} = translation, chapter_id) do
    Repo.get_by(ChapterDocument, translation_id: translation.id, chapter_id: chapter_id)
  end

  @doc """
  Bundled chapter text for rendering: document blocks and footnotes.
  Returns `nil` when the translation or chapter document has not been imported.
  """
  def get_chapter_content(%Translation{} = translation, chapter_id) do
    case get_chapter_document(translation, chapter_id) do
      nil ->
        nil

      document ->
        %{
          blocks: document.blocks_json,
          footnotes: list_footnotes_for_chapter(translation, chapter_id)
        }
    end
  end

  @doc """
  Footnotes for a chapter, ordered for display (by verse, then position).
  """
  def list_footnotes_for_chapter(%Translation{} = translation, chapter_id) do
    from(f in Footnote,
      join: v in Verse,
      on: f.verse_id == v.id,
      where: v.translation_id == ^translation.id and v.chapter_id == ^chapter_id,
      order_by: [asc: v.verse_number, asc: f.position],
      select: f
    )
    |> Repo.all()
  end

  @doc """
  Upserts a translation by code.
  """
  def upsert_translation(attrs) when is_map(attrs) do
    code = Map.fetch!(attrs, :code)

    case Repo.get_by(Translation, code: code) do
      nil ->
        %Translation{}
        |> Translation.changeset(attrs)
        |> Repo.insert()

      translation ->
        translation
        |> Translation.changeset(attrs)
        |> Repo.update()
    end
  end
end

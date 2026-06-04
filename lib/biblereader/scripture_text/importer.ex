defmodule BibleReader.ScriptureText.Importer do
  @moduledoc """
  Imports parsed USFM books into `bible_translations`, `chapter_documents`,
  `bible_verses`, and `bible_footnotes`.

  Limitations (translations supported, re-import, book codes): `docs/scripture-text-import.md`.
  """

  import Ecto.Query

  alias BibleReader.Repo
  alias BibleReader.Scripture
  alias BibleReader.ScriptureText
  alias BibleReader.ScriptureText.{ChapterDocument, Footnote, Translation, Verse}
  alias BibleReader.ScriptureText.Usfm.Parser
  alias Ecto.Multi

  @deuelbbk_attrs %{
    code: "deuelbbk",
    name: "Elberfelder Übersetzung",
    language: "de",
    source_format: "usfm",
    license: "Copyright bibelkommentare.de — local dev import only",
    copyright_notice:
      "Elberfelder Übersetzung (Version 1.2 von bibelkommentare.de). Distributed via eBible.org.",
    source_path: "deuelbbk_usfm.zip"
  }

  @doc """
  Imports all `.usfm` files from `source_dir` for the given translation code.
  Currently only `deuelbbk` is supported.
  """
  @spec import_translation(String.t(), String.t()) :: {:ok, Translation.t()} | {:error, term()}
  def import_translation("deuelbbk", source_dir) when is_binary(source_dir) do
    with {:ok, translation} <- ScriptureText.upsert_translation(@deuelbbk_attrs),
         :ok <- import_all_books(translation, source_dir) do
      {:ok, translation}
    end
  end

  def import_translation(code, _source_dir) do
    {:error, {:unsupported_translation, code}}
  end

  @doc """
  Imports a single USFM book file.
  """
  @spec import_book_file(Translation.t(), String.t()) :: :ok | {:error, term()}
  def import_book_file(%Translation{} = translation, path) when is_binary(path) do
    filename = Path.basename(path)
    usfm = File.read!(path)
    parsed = Parser.parse_book(usfm, filename: filename)

    case Scripture.get_book_by_code(parsed.book_code) do
      nil ->
        {:error, {:unknown_book, parsed.book_code, filename}}

      book ->
        import_parsed_book(translation, book.id, parsed)
    end
  end

  defp import_all_books(translation, source_dir) do
    source_dir
    |> Path.join("*.usfm")
    |> Path.wildcard()
    |> Enum.sort()
    |> Enum.reduce(:ok, fn path, :ok ->
      case import_book_file(translation, path) do
        :ok ->
          :ok

        {:error, {:unknown_book, code, filename}} ->
          IO.warn("Skipping #{filename}: unknown book code #{code}")
          :ok

        other ->
          other
      end
    end)
  end

  defp import_parsed_book(translation, book_id, parsed) do
    chapters_by_number =
      book_id
      |> Scripture.list_chapters_for_book()
      |> Map.new(&{&1.chapter_number, &1})

    parsed.chapters
    |> Enum.reduce_while(:ok, fn chapter, :ok ->
      case Map.get(chapters_by_number, chapter.number) do
        nil ->
          IO.warn("Skipping #{parsed.book_code} chapter #{chapter.number}: not in catalog")
          {:cont, :ok}

        catalog_chapter ->
          case import_chapter(translation, catalog_chapter, chapter) do
            :ok -> {:cont, :ok}
            {:error, reason} -> {:halt, {:error, reason}}
          end
      end
    end)
  end

  defp import_chapter(translation, catalog_chapter, chapter) do
    multi =
      Multi.new()
      |> Multi.delete_all(:clear_footnotes, footnotes_query(translation.id, catalog_chapter.id))
      |> Multi.delete_all(:clear_verses, verses_query(translation.id, catalog_chapter.id))
      |> Multi.delete_all(:clear_document, document_query(translation.id, catalog_chapter.id))
      |> Multi.insert(:document, fn _ ->
        ChapterDocument.changeset(%ChapterDocument{}, %{
          translation_id: translation.id,
          chapter_id: catalog_chapter.id,
          blocks_json: chapter.blocks
        })
      end)

    {multi, _display} =
      Enum.reduce(chapter.verses, {multi, 1}, fn verse, {m, display_num} ->
        m =
          Multi.insert(m, {:verse, verse.number}, fn _ ->
            Verse.changeset(%Verse{}, %{
              translation_id: translation.id,
              chapter_id: catalog_chapter.id,
              verse_number: verse.number,
              plain_text: verse.plain_text,
              content_json: verse.content_json
            })
          end)

        Enum.reduce(verse.footnotes, {m, display_num}, fn footnote, {m2, num} ->
          m2 =
            Multi.insert(m2, {:footnote, footnote.id}, fn changes ->
              verse_row = Map.fetch!(changes, {:verse, verse.number})

              Footnote.changeset(%Footnote{}, %{
                verse_id: verse_row.id,
                ref_id: footnote.id,
                marker: footnote.marker,
                body: footnote.body,
                position: footnote.position,
                display_number: num
              })
            end)

          {m2, num + 1}
        end)
      end)

    case Repo.transaction(multi) do
      {:ok, _} -> :ok
      {:error, _step, reason, _} -> {:error, reason}
    end
  end

  defp footnotes_query(translation_id, chapter_id) do
    from(f in Footnote,
      join: v in Verse,
      on: f.verse_id == v.id,
      where: v.translation_id == ^translation_id and v.chapter_id == ^chapter_id
    )
  end

  defp verses_query(translation_id, chapter_id) do
    from(v in Verse,
      where: v.translation_id == ^translation_id and v.chapter_id == ^chapter_id
    )
  end

  defp document_query(translation_id, chapter_id) do
    from(d in ChapterDocument,
      where: d.translation_id == ^translation_id and d.chapter_id == ^chapter_id
    )
  end

  @doc """
  Extracts `deuelbbk_usfm.zip` to `priv/scripture/usfm/deuelbbk/` if needed.
  Returns the extraction directory path.
  """
  @spec ensure_deuelbbk_extracted!() :: String.t()
  def ensure_deuelbbk_extracted! do
    zip_path = deuelbbk_zip_path()

    dest_dir =
      Path.join([Application.app_dir(:biblereader, "priv"), "scripture", "usfm", "deuelbbk"])

    marker = Path.join(dest_dir, ".extracted")

    if File.exists?(marker) do
      dest_dir
    else
      File.mkdir_p!(dest_dir)

      case System.cmd("unzip", ["-o", zip_path, "-d", dest_dir, "*.usfm"], stderr_to_stdout: true) do
        {_output, 0} ->
          File.write!(marker, DateTime.utc_now() |> DateTime.to_iso8601())
          dest_dir

        {output, code} ->
          raise "failed to unzip #{zip_path} (exit #{code}): #{output}"
      end
    end
  end

  defp deuelbbk_zip_path do
    candidates = [
      Path.expand("deuelbbk_usfm.zip", File.cwd!()),
      Path.expand("../../deuelbbk_usfm.zip", Application.app_dir(:biblereader, "priv"))
    ]

    Enum.find(candidates, &File.exists?/1) ||
      raise "deuelbbk_usfm.zip not found (expected in project root)"
  end
end

defmodule BibleReader.ScriptureTextFixtures do
  @moduledoc false

  alias BibleReader.ScriptureFixtures
  alias BibleReader.ScriptureText.Importer

  @genesis_fixture Path.expand("fixtures/usfm/genesis_1_snippet.usfm", __DIR__)

  def import_genesis_snippet! do
    {:ok, translation} =
      BibleReader.ScriptureText.upsert_translation(%{
        code: "deuelbbk",
        name: "Elberfelder Übersetzung",
        language: "de",
        source_format: "usfm",
        license: "test",
        copyright_notice: "test fixture",
        source_path: "genesis_1_snippet.usfm"
      })

    ScriptureFixtures.book_and_chapter_fixture(%{
      code: "GEN",
      name: "Genesis",
      sort_order: 1,
      testament: "ot"
    })

    :ok = Importer.import_book_file(translation, @genesis_fixture)
    translation
  end
end

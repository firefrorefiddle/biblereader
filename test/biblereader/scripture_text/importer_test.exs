defmodule BibleReader.ScriptureText.ImporterTest do
  use BibleReader.DataCase, async: false

  alias BibleReader.ScriptureFixtures
  alias BibleReader.ScriptureText
  alias BibleReader.ScriptureText.Importer

  @genesis_fixture Path.expand("../../support/fixtures/usfm/genesis_1_snippet.usfm", __DIR__)

  test "imports genesis snippet with verses and footnotes" do
    %{chapter: chapter} =
      ScriptureFixtures.book_and_chapter_fixture(%{
        code: "GEN",
        name: "Genesis",
        sort_order: 1,
        testament: "ot"
      })

    {:ok, translation} =
      ScriptureText.upsert_translation(%{
        code: "deuelbbk",
        name: "Elberfelder Übersetzung",
        language: "de",
        source_format: "usfm"
      })

    assert :ok = Importer.import_book_file(translation, @genesis_fixture)

    content = ScriptureText.get_chapter_content(translation, chapter.id)
    assert content
    assert length(content.footnotes) >= 1

    document = ScriptureText.get_chapter_document(translation, chapter.id)
    assert document
  end
end

defmodule BibleReader.ScriptureTextTest do
  use BibleReader.DataCase, async: false

  alias BibleReader.ScriptureText
  alias BibleReader.ScriptureTextFixtures

  setup do
    translation = ScriptureTextFixtures.import_genesis_snippet!()
    chapter = BibleReader.Scripture.get_chapter_by_code_and_number("GEN", 1)
    %{chapter: chapter, translation: translation}
  end

  test "get_chapter_content/2 returns blocks and footnotes", %{
    chapter: chapter,
    translation: translation
  } do
    content = ScriptureText.get_chapter_content(translation, chapter.id)
    assert content
    assert Enum.any?(content.blocks, &(&1["type"] == "paragraph"))
    assert Enum.any?(content.footnotes, &String.contains?(&1.body, "Im Hebr."))
  end

  test "get_default_translation/0", %{translation: translation} do
    assert ScriptureText.get_default_translation().id == translation.id
  end
end

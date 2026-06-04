defmodule BibleReader.ScriptureText.Usfm.ParserTest do
  use ExUnit.Case, async: true

  alias BibleReader.ScriptureText.Usfm.{BookCode, Parser, Tokenizer}

  @fixture Path.expand("../../../support/fixtures/usfm/genesis_1_snippet.usfm", __DIR__)

  describe "BookCode" do
    test "maps JOL to JOE" do
      assert BookCode.normalize("JOL") == "JOE"
    end

    test "extracts code from filename" do
      assert BookCode.from_filename("02-GENdeuelbbk.usfm") == "GEN"
      assert BookCode.from_filename("30-JOLdeuelbbk.usfm") == "JOE"
    end
  end

  describe "parse_book/1" do
    setup do
      usfm = File.read!(@fixture)
      %{usfm: usfm, book: Parser.parse_book(usfm, filename: "02-GENdeuelbbk.usfm")}
    end

    test "detects book code and title", %{book: book} do
      assert book.book_code == "GEN"
      assert book.title == "1. Mose"
    end

    test "parses chapter 1 verses", %{book: book} do
      chapter = Enum.find(book.chapters, &(&1.number == 1))
      assert chapter
      assert length(chapter.verses) >= 3

      verse1 = Enum.find(chapter.verses, &(&1.number == 1))
      assert verse1.plain_text =~ "Im Anfang schuf Gott"
      assert verse1.plain_text =~ "und die Erde"
      refute verse1.plain_text =~ "Im Hebr."

      assert Enum.any?(verse1.content_json, &(&1["type"] == "footnote_ref"))
      assert [footnote | _] = verse1.footnotes
      assert footnote.body =~ "Im Hebr."
      assert footnote.marker == "-"
    end

    test "builds paragraph blocks with verse markers", %{book: book} do
      chapter = Enum.find(book.chapters, &(&1.number == 1))
      assert Enum.any?(chapter.blocks, &(&1["type"] == "paragraph"))

      paragraph = hd(chapter.blocks)
      assert Enum.any?(paragraph["content"], &(&1["type"] == "verse"))
    end
  end

  describe "Tokenizer" do
    test "tokenizes footnote markers" do
      tokens = Tokenizer.tokenize("\\v 1 Hello\\f - \\fr 1,1 \\ft Note\\f* world")

      assert {:open, "v", "1 Hello"} in tokens
      assert {:open, "f", "-"} in tokens
      assert {:open, "fr", "1,1"} in tokens
      assert {:open, "ft", "Note"} in tokens
      assert {:close, "f"} in tokens
      assert {:text, "world"} in tokens
    end
  end
end

defmodule BibleReaderWeb.ScriptureComponentsTest do
  use ExUnit.Case, async: true

  import Phoenix.LiveViewTest

  alias BibleReader.ScriptureText.Usfm.Parser

  @fixture Path.expand("../../support/fixtures/usfm/genesis_1_snippet.usfm", __DIR__)

  describe "chapter_content/1" do
    setup do
      usfm = File.read!(@fixture)
      book = Parser.parse_book(usfm, filename: "02-GENdeuelbbk.usfm")
      chapter = Enum.find(book.chapters, &(&1.number == 1))
      verse1 = Enum.find(chapter.verses, &(&1.number == 1))
      [footnote | _] = verse1.footnotes

      block =
        Enum.find(chapter.blocks, fn block ->
          Enum.any?(block["content"] || [], &(&1["type"] == "verse" and &1["number"] == 1))
        end)

      footnote_entry = %{
        ref_id: footnote.id,
        body: footnote.body,
        display_number: 1
      }

      html =
        render_component(&BibleReaderWeb.ScriptureComponents.chapter_content/1,
          blocks: [block],
          footnotes: [footnote_entry]
        )

      %{html: html, footnote_id: footnote.id}
    end

    test "renders footnote marker tight against preceding text", %{html: html, footnote_id: id} do
      refute html =~ ~r/Himmel\s+<a/
      assert html =~ ~r/Himmel<a[^>]+href="#footnote-#{id}"/
    end

    test "renders space after footnote when followed by word text", %{html: html} do
      assert html =~ ~r{</a> und die Erde}
      refute html =~ ~r{</a>und die Erde}
    end

    test "renders footnote before punctuation without extra space" do
      usfm = File.read!("priv/scripture/usfm/deuelbbk/03-EXOdeuelbbk.usfm")
      book = Parser.parse_book(usfm, filename: "03-EXOdeuelbbk.usfm")
      chapter = Enum.find(book.chapters, &(&1.number == 33))
      verse6 = Enum.find(chapter.verses, &(&1.number == 6))
      [footnote | _] = verse6.footnotes

      block =
        Enum.find(chapter.blocks, fn block ->
          Enum.any?(block["content"] || [], &(&1["type"] == "verse" and &1["number"] == 6))
        end)

      html =
        render_component(&BibleReaderWeb.ScriptureComponents.chapter_content/1,
          blocks: [block],
          footnotes: [
            %{ref_id: footnote.id, body: footnote.body, display_number: 1}
          ]
        )

      refute html =~ ~r/Horeb\s+<a/
      refute html =~ ~r{</a>\s+\.}
      assert html =~ ~r{Horeb<a[^>]+>¹</a>\.}
    end

    test "renders space after mid-verse footnote before following word (GAL 6:9)" do
      usfm = File.read!("priv/scripture/usfm/deuelbbk/54-GALdeuelbbk.usfm")
      book = Parser.parse_book(usfm, filename: "54-GALdeuelbbk.usfm")
      chapter = Enum.find(book.chapters, &(&1.number == 6))
      verse9 = Enum.find(chapter.verses, &(&1.number == 9))
      footnotes = verse9.footnotes

      block =
        Enum.find(chapter.blocks, fn block ->
          Enum.any?(block["content"] || [], &(&1["type"] == "verse" and &1["number"] == 9))
        end)

      footnote_entries =
        Enum.with_index(footnotes, 1)
        |> Enum.map(fn {fnote, n} ->
          %{ref_id: fnote.id, body: fnote.body, display_number: n}
        end)

      html =
        render_component(&BibleReaderWeb.ScriptureComponents.chapter_content/1,
          blocks: [block],
          footnotes: footnote_entries
        )

      [first_fnote | _] = footnotes
      assert html =~ ~r/müde<a[^>]+href="#footnote-#{first_fnote.id}"/
      assert html =~ ~r{</a> werden}
      refute html =~ ~r{</a>werden}
    end
  end
end

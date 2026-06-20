defmodule BibleReader.ScriptureText.Usfm.Parser do
  @moduledoc """
  Parses USFM book files into chapter documents, verse indexes, and footnotes.

  v1 supports: `\\c`, `\\p`, `\\v`, `\\f` footnotes with `\\fr` / `\\ft`.
  Character styles (`\\em`, `\\add`, `\\nd`, etc.) are flattened to plain text.

  Full limitation list and roadmap: `docs/scripture-text-import.md`.
  """

  alias BibleReader.ScriptureText.Usfm.{BookCode, Tokenizer}

  @skip_markers ~w(id toc1 toc2 toc3 mt1 mt2 mt3 s s1 s2 s3 s4)
  @char_markers ~w(em add nd +em +add +nd)

  @type footnote :: %{
          id: String.t(),
          marker: String.t(),
          body: String.t(),
          position: non_neg_integer()
        }

  @type verse :: %{
          number: pos_integer(),
          plain_text: String.t(),
          content_json: [map()],
          footnotes: [footnote()]
        }

  @type chapter :: %{
          number: pos_integer(),
          blocks: [map()],
          verses: [verse()]
        }

  @type book :: %{
          book_code: String.t(),
          title: String.t() | nil,
          chapters: [chapter()]
        }

  @doc """
  Parses a full USFM book file.
  """
  @spec parse_book(String.t(), keyword()) :: book()
  def parse_book(usfm, opts \\ []) when is_binary(usfm) do
    filename = Keyword.get(opts, :filename)
    book_code = book_code_from_usfm(usfm, filename)
    title = title_from_usfm(usfm)

    usfm
    |> Tokenizer.tokenize()
    |> build_chapters()
    |> then(fn chapters ->
      %{
        book_code: book_code,
        title: title,
        chapters: chapters
      }
    end)
  end

  defp book_code_from_usfm(usfm, filename) do
    id_line =
      usfm
      |> String.split("\n", parts: 2)
      |> List.first()

    BookCode.from_id_line(id_line) ||
      (filename && BookCode.from_filename(filename)) ||
      raise "could not determine book code from USFM"
  end

  defp title_from_usfm(usfm) do
    case Regex.run(~r/^\\mt1\s+(.+)$/m, usfm) do
      [_, title] -> String.trim(title)
      _ -> nil
    end
  end

  defp build_chapters(tokens) do
    tokens
    |> Enum.reduce({[], nil, empty_chapter_state()}, &reduce_token/2)
    |> finalize_chapter()
    |> elem(0)
    |> Enum.reverse()
    |> Enum.map(&finalize_chapter_struct/1)
  end

  defp reduce_token({:open, "c", payload}, acc) do
    {chapters, current, state} = acc
    {chapters, _closed, _state} = maybe_close_chapter(chapters, current, state)
    chapter_num = parse_leading_integer(payload)
    {chapters, chapter_num, fresh_chapter_state(chapter_num)}
  end

  defp reduce_token({:open, "p", _payload}, {chapters, current, state}) do
    {chapters, current, start_paragraph(state, "p")}
  end

  defp reduce_token({:open, "v", payload}, {chapters, current, state}) do
    {verse_num, rest} = parse_verse_payload(payload)
    state = close_paragraph_if_needed(state)

    state =
      state
      |> start_paragraph_if_needed("p")
      |> start_verse(verse_num)
      |> append_inline(%{"type" => "verse", "number" => verse_num})

    state =
      if rest != "" do
        append_text(state, rest)
      else
        state
      end

    {chapters, current, state}
  end

  defp reduce_token({:open, "f", payload}, {chapters, current, state}) do
    marker = footnote_marker(payload)
    id = Ecto.UUID.generate()

    state =
      state
      |> ensure_verse()
      |> add_footnote_ref(id, marker)

    active_footnote = %{
      id: id,
      marker: marker,
      fr: "",
      ft: "",
      position: length(state.footnotes)
    }

    {chapters, current, %{state | footnote: active_footnote, footnote_part: nil}}
  end

  defp reduce_token(
         {:open, "fr", payload},
         {chapters, current, %{footnote: active_footnote} = state}
       )
       when not is_nil(active_footnote) do
    state =
      state
      |> put_in([:footnote, :fr], strip_char_markup(payload))
      |> Map.put(:footnote_part, :fr)

    {chapters, current, state}
  end

  defp reduce_token(
         {:open, "ft", payload},
         {chapters, current, %{footnote: active_footnote} = state}
       )
       when not is_nil(active_footnote) do
    state =
      state
      |> append_footnote_field(:ft, payload)
      |> Map.put(:footnote_part, :ft)

    {chapters, current, state}
  end

  defp reduce_token({:close, "f"}, {chapters, current, %{footnote: active_footnote} = state})
       when not is_nil(active_footnote) do
    body =
      [active_footnote.fr, active_footnote.ft]
      |> Enum.reject(&(&1 == ""))
      |> Enum.join(" ")
      |> String.trim()

    footnote = %{
      id: active_footnote.id,
      marker: active_footnote.marker,
      body: body,
      position: active_footnote.position,
      verse_number: state.current_verse
    }

    state = %{
      state
      | footnotes: state.footnotes ++ [footnote],
        footnote: nil,
        footnote_part: nil
    }

    {chapters, current, state}
  end

  defp reduce_token({:open, marker, _payload}, acc) when marker in @skip_markers, do: acc

  defp reduce_token({:open, marker, payload}, {chapters, current, %{footnote: active} = state})
       when not is_nil(active) and marker in @char_markers do
    part = state.footnote_part || :ft
    {chapters, current, append_footnote_field(state, part, payload)}
  end

  defp reduce_token({:close, marker}, {chapters, current, %{footnote: active} = state})
       when not is_nil(active) and marker in @char_markers do
    {chapters, current, state}
  end

  defp reduce_token({:open, marker, payload}, {chapters, current, state})
       when marker in @char_markers do
    {chapters, current, append_text(state, strip_char_markup(payload))}
  end

  defp reduce_token({:close, marker}, {chapters, current, state})
       when marker in @char_markers do
    {chapters, current, state}
  end

  defp reduce_token({:open, _marker, _payload}, acc), do: acc

  defp reduce_token({:close, _marker}, acc), do: acc

  defp reduce_token({:text, text}, {chapters, current, %{footnote: active} = state})
       when not is_nil(active) do
    part = state.footnote_part || :ft
    {chapters, current, append_footnote_field(state, part, text)}
  end

  defp reduce_token({:text, text}, {chapters, current, state}) do
    cleaned = strip_char_markup(text)
    {chapters, current, append_text(state, cleaned)}
  end

  defp maybe_close_chapter(chapters, nil, state), do: {chapters, nil, state}

  defp maybe_close_chapter(chapters, current, state) do
    {chapters ++ [finalize_chapter_state(state)], current, state}
  end

  defp finalize_chapter({chapters, current, state}) do
    chapters =
      if current do
        chapters ++ [finalize_chapter_state(state)]
      else
        chapters
      end

    {chapters, current, state}
  end

  defp empty_chapter_state do
    %{
      number: nil,
      blocks: [],
      paragraph: nil,
      current_verse: nil,
      verses: %{},
      footnotes: [],
      footnote: nil,
      footnote_part: nil
    }
  end

  defp fresh_chapter_state(number) do
    empty_chapter_state()
    |> Map.put(:number, number)
  end

  defp finalize_chapter_struct(%{number: number} = state) when is_integer(number) do
    state = finalize_open_paragraph(state)
    state = finalize_open_verse(state)

    verses =
      state.verses
      |> Map.values()
      |> Enum.sort_by(& &1.number)
      |> Enum.map(fn verse ->
        footnotes =
          state.footnotes
          |> Enum.filter(&(&1.verse_number == verse.number))
          |> Enum.map(fn fnote ->
            Map.drop(fnote, [:verse_number])
          end)

        Map.put(verse, :footnotes, footnotes)
      end)

    %{
      number: number,
      blocks: Enum.reverse(state.blocks),
      verses: verses
    }
  end

  defp finalize_chapter_state(state) do
    state
    |> finalize_open_paragraph()
    |> finalize_open_verse()
  end

  defp start_paragraph(state, kind) do
    state
    |> finalize_open_paragraph()
    |> Map.put(:paragraph, %{kind: kind, content: []})
  end

  defp start_paragraph_if_needed(%{paragraph: nil} = state, kind),
    do: start_paragraph(state, kind)

  defp start_paragraph_if_needed(state, _kind), do: state

  defp close_paragraph_if_needed(%{paragraph: nil} = state), do: state

  defp close_paragraph_if_needed(state), do: finalize_open_paragraph(state)

  defp finalize_open_paragraph(%{paragraph: %{content: []}} = state) do
    %{state | paragraph: nil}
  end

  defp finalize_open_paragraph(%{paragraph: nil} = state), do: state

  defp finalize_open_paragraph(%{paragraph: paragraph} = state) do
    content = merge_text_nodes(paragraph.content)

    block = %{
      "type" => "paragraph",
      "kind" => paragraph.kind,
      "content" => content
    }

    %{
      state
      | blocks: [block | state.blocks],
        paragraph: nil
    }
  end

  defp start_verse(state, verse_num) do
    state = finalize_open_verse(state)

    verse = %{
      number: verse_num,
      inline: []
    }

    %{state | current_verse: verse_num, verses: Map.put(state.verses, verse_num, verse)}
  end

  defp ensure_verse(%{current_verse: nil} = state) do
    # Footnote before explicit verse marker — attach to verse 1
    start_verse(state, 1)
  end

  defp ensure_verse(state), do: state

  defp finalize_open_verse(%{current_verse: nil} = state), do: state

  defp finalize_open_verse(%{current_verse: verse_num, verses: verses} = state) do
    verse = Map.fetch!(verses, verse_num)
    inline = merge_text_nodes(verse.inline)
    plain_text = inline_to_plain_text(inline)

    finalized = %{
      number: verse_num,
      plain_text: plain_text,
      content_json: inline,
      footnotes: []
    }

    %{
      state
      | verses: Map.put(verses, verse_num, finalized),
        current_verse: nil
    }
  end

  defp append_text(%{current_verse: nil} = state, ""), do: state

  defp append_text(%{current_verse: nil} = state, text) do
    state
    |> start_paragraph_if_needed("p")
    |> start_verse(1)
    |> append_text(text)
  end

  defp append_text(%{current_verse: verse_num, verses: verses} = state, text) do
    verse = Map.fetch!(verses, verse_num)
    inline = verse.inline ++ [%{"type" => "text", "text" => normalize_space(text)}]
    verses = Map.put(verses, verse_num, %{verse | inline: inline})
    state = %{state | verses: verses}
    append_paragraph_text(state, text)
  end

  defp append_paragraph_text(%{paragraph: nil} = state, _text), do: state

  defp append_paragraph_text(%{paragraph: paragraph} = state, text) do
    content = paragraph.content ++ [%{"type" => "text", "text" => normalize_space(text)}]
    %{state | paragraph: %{paragraph | content: content}}
  end

  defp append_inline(state, node) do
    state = append_paragraph_inline(state, node)

    case state.current_verse do
      nil ->
        state

      verse_num ->
        verse = Map.fetch!(state.verses, verse_num)
        inline = verse.inline ++ [node]
        verses = Map.put(state.verses, verse_num, %{verse | inline: inline})
        %{state | verses: verses}
    end
  end

  defp append_paragraph_inline(%{paragraph: nil} = state, node) do
    state |> start_paragraph("p") |> append_paragraph_inline(node)
  end

  defp append_paragraph_inline(%{paragraph: paragraph} = state, node) do
    %{state | paragraph: %{paragraph | content: paragraph.content ++ [node]}}
  end

  defp add_footnote_ref(state, id, marker) do
    node = %{"type" => "footnote_ref", "id" => id, "marker" => marker}
    append_inline(state, node)
  end

  defp parse_leading_integer(payload) do
    case Regex.run(~r/^(\d+)/, String.trim(payload)) do
      [_, num] -> String.to_integer(num)
      _ -> raise "invalid chapter number: #{inspect(payload)}"
    end
  end

  defp parse_verse_payload(payload) do
    case Regex.run(~r/^(\d+)\s*(.*)$/s, String.trim(payload)) do
      [_, num, rest] -> {String.to_integer(num), String.trim(rest)}
      _ -> raise "invalid verse marker payload: #{inspect(payload)}"
    end
  end

  defp append_footnote_field(%{footnote: active} = state, :fr, text) do
    fr = append_field_text(active.fr, text)
    put_in(state.footnote.fr, normalize_space(fr))
  end

  defp append_footnote_field(%{footnote: active} = state, :ft, text) do
    ft = append_field_text(active.ft, strip_char_markup(text))
    put_in(state.footnote.ft, normalize_space(ft))
  end

  defp append_field_text("", text), do: text
  defp append_field_text(prev, text), do: prev <> " " <> text

  defp footnote_marker(payload) do
    payload
    |> String.trim()
    |> String.split(~r/\s+/, parts: 2)
    |> List.first()
    |> Kernel.||("-")
  end

  defp strip_char_markup(text) do
    text
    |> String.replace(~r/\\\+?[a-z]+\*?\s?/i, "")
    |> normalize_space()
  end

  defp normalize_space(text) do
    text
    |> String.replace(~r/\s+/, " ")
    |> String.trim()
  end

  defp merge_text_nodes(nodes) do
    Enum.reduce(nodes, [], fn
      %{"type" => "text", "text" => text}, [%{"type" => "text", "text" => prev} | rest] ->
        [%{"type" => "text", "text" => String.trim(prev <> " " <> text)} | rest]

      node, acc ->
        [node | acc]
    end)
    |> Enum.reverse()
  end

  defp inline_to_plain_text(nodes) do
    text =
      nodes
      |> Enum.flat_map(fn
        %{"type" => "text", "text" => text} -> [text]
        _ -> []
      end)
      |> Enum.join(" ")
      |> normalize_space()

    text
  end
end

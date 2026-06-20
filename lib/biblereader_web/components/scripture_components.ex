defmodule BibleReaderWeb.ScriptureComponents do
  @moduledoc """
  Renders imported chapter scripture text and footnotes.
  """
  use Phoenix.Component

  @superscript ~w(⁰ ¹ ² ³ ⁴ ⁵ ⁶ ⁷ ⁸ ⁹)

  @doc """
  Renders a chapter document (paragraph blocks) and footnote list.
  """
  attr :blocks, :list, required: true
  attr :footnotes, :list, required: true

  def chapter_content(assigns) do
    footnotes_by_id =
      assigns.footnotes
      |> Map.new(fn fnote -> {fnote.ref_id, fnote} end)

    assigns =
      assigns
      |> assign(:footnotes_by_id, footnotes_by_id)
      |> assign(:footnote_glyphs, footnote_glyphs(assigns.footnotes))

    ~H"""
    <article class="scripture-text font-serif text-[1.05rem] leading-relaxed text-zinc-800">
      <div class="space-y-4">
        <%= for block <- @blocks do %>
          <.paragraph_block
            block={block}
            footnotes_by_id={@footnotes_by_id}
            footnote_glyphs={@footnote_glyphs}
          />
        <% end %>
      </div>

      <footer :if={@footnotes != []} class="mt-8 border-t border-zinc-200 pt-4">
        <h3 class="mb-3 text-xs font-semibold uppercase tracking-wide text-zinc-500">Footnotes</h3>
        <ol class="space-y-2 text-sm leading-relaxed text-zinc-700">
          <%= for footnote <- @footnotes do %>
            <li id={"footnote-#{footnote.ref_id}"} class="flex gap-2">
              <span class="shrink-0 font-medium text-zinc-500">
                [{footnote_glyph(@footnote_glyphs, footnote.ref_id)}]
              </span>
              <span>{footnote.body}</span>
            </li>
          <% end %>
        </ol>
      </footer>
    </article>
    """
  end

  attr :block, :map, required: true
  attr :footnotes_by_id, :map, required: true
  attr :footnote_glyphs, :map, required: true

  defp paragraph_block(assigns) do
    nodes = assigns.block["content"] || []

    assigns =
      assigns
      |> assign(:nodes, nodes)
      |> assign(:node_pairs, Enum.with_index(nodes))

    ~H"""
    <p :if={@block["type"] == "paragraph"} class="indent-0">
      <.inline_node
        :for={{node, index} <- @node_pairs}
        node={node}
        next_node={Enum.at(@nodes, index + 1)}
        footnotes_by_id={@footnotes_by_id}
        footnote_glyphs={@footnote_glyphs}
      />
    </p>
    """
  end

  attr :node, :map, required: true
  attr :next_node, :map, default: nil
  attr :footnotes_by_id, :map, required: true
  attr :footnote_glyphs, :map, required: true

  defp inline_node(%{node: %{"type" => "verse", "number" => number}} = assigns) do
    assigns = assign(assigns, :number, number)

    ~H"""
    <sup class="mr-1 text-xs font-semibold text-zinc-500">{@number}</sup>
    """
  end

  defp inline_node(%{node: %{"type" => "footnote_ref", "id" => id}} = assigns) do
    glyph = footnote_glyph(assigns.footnote_glyphs, id)

    assigns =
      assigns
      |> assign(:id, id)
      |> assign(:glyph, glyph)
      |> assign(:footnote_markup, footnote_markup(id, glyph))
      |> assign(:trail_space, footnote_trailing_space(assigns.next_node))

    ~H"""
    {@footnote_markup}{@trail_space}
    """
  end

  defp inline_node(%{node: %{"type" => "text", "text" => text}} = assigns) do
    assigns = assign(assigns, :text, text)

    ~H"""
    {@text}
    """
  end

  defp inline_node(assigns), do: ~H""

  defp footnote_glyphs(footnotes) do
    Map.new(footnotes, fn fnote -> {fnote.ref_id, glyph_for_number(fnote.display_number)} end)
  end

  defp footnote_glyph(glyphs, id), do: Map.get(glyphs, id, "*")

  defp footnote_markup(id, glyph) do
    ~s(<a href="#footnote-#{id}" class="align-super text-xs font-medium text-primary no-underline hover:underline" aria-label="Footnote #{glyph}">#{glyph}</a>)
    |> Phoenix.HTML.raw()
  end

  defp glyph_for_number(number) when number in 1..9, do: Enum.at(@superscript, number)
  defp glyph_for_number(number), do: Integer.to_string(number)

  defp footnote_trailing_space(%{"type" => "text", "text" => text}) when text != "" do
    if String.match?(text, ~r/^[\.,;:!?\)\]'"-]/) do
      ""
    else
      " "
    end
  end

  defp footnote_trailing_space(_), do: ""
end

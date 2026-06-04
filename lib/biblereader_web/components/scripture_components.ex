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
    ~H"""
    <p :if={@block["type"] == "paragraph"} class="indent-0">
      <%= for node <- @block["content"] || [] do %>
        <.inline_node
          node={node}
          footnotes_by_id={@footnotes_by_id}
          footnote_glyphs={@footnote_glyphs}
        />
      <% end %>
    </p>
    """
  end

  attr :node, :map, required: true
  attr :footnotes_by_id, :map, required: true
  attr :footnote_glyphs, :map, required: true

  defp inline_node(%{node: %{"type" => "verse", "number" => number}} = assigns) do
    assigns = assign(assigns, :number, number)

    ~H"""
    <sup class="mr-1 text-xs font-semibold text-zinc-500">{@number}</sup>
    """
  end

  defp inline_node(%{node: %{"type" => "footnote_ref", "id" => id}} = assigns) do
    assigns =
      assigns
      |> assign(:id, id)
      |> assign(:glyph, footnote_glyph(assigns.footnote_glyphs, id))

    ~H"""
    <a
      href={"#footnote-#{@id}"}
      class="mx-0.5 align-super text-xs font-medium text-primary no-underline hover:underline"
      aria-label={"Footnote #{@glyph}"}
    >
      {@glyph}
    </a>
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

  defp glyph_for_number(number) when number in 1..9, do: Enum.at(@superscript, number)
  defp glyph_for_number(number), do: Integer.to_string(number)
end

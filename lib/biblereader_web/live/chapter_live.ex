defmodule BibleReaderWeb.ChapterLive do
  @moduledoc """
  Chapter reading view: mark as read, history, per-chapter note, scripture placeholder.
  """
  use BibleReaderWeb, :live_view

  alias BibleReader.Accounts
  alias BibleReader.Notes
  alias BibleReader.ReadingPlan
  alias BibleReader.ReadingPlan.RelativeTime
  alias BibleReader.Scripture
  alias BibleReader.ScriptureText
  alias BibleReaderWeb.RelativeTimeFormat
  alias BibleReaderWeb.EffectiveDate, as: EffectiveDateUI

  @impl true
  def render(assigns) do
    ~H"""
    <div class="mx-auto max-w-5xl px-1 py-6 sm:px-2">
      <nav class="mb-4 text-sm">
        <.link navigate={~p"/read/books/#{@book.code}"} class="text-primary hover:underline">
          ← {@book_name}
        </.link>
      </nav>

      <div class="lg:grid lg:grid-cols-2 lg:gap-8">
        <div>
          <header class="mb-6 flex flex-wrap items-start justify-between gap-4 border-b border-zinc-200 pb-4">
            <div>
              <h1 class="font-serif text-2xl font-semibold text-zinc-900">
                {@book_name} {@chapter.chapter_number}
              </h1>
              <p class="mt-1 text-sm text-zinc-600">
                <span :if={@read_count > 0}>
                  {gettext("Last read: %{label} · Read count: %{count}",
                    label: @last_read_label,
                    count: @read_count
                  )}
                </span>
                <span :if={@read_count == 0}>{gettext("Not read yet")}</span>
              </p>
            </div>
            <button
              type="button"
              phx-click="log_read"
              class="shrink-0 rounded-lg bg-primary px-4 py-2.5 text-sm font-medium text-white hover:bg-primary/90"
            >
              {gettext("Mark as read")}
            </button>
          </header>

          <div class="rounded-xl border border-zinc-200 bg-card p-6 shadow-sm">
            <p :if={@scripture_content} class="text-sm font-medium text-zinc-500">
              {@translation.name}
            </p>
            <.chapter_content
              :if={@scripture_content}
              blocks={@scripture_content.blocks}
              footnotes={@scripture_content.footnotes}
            />
            <div :if={is_nil(@scripture_content)}>
              <p class="text-sm font-medium text-zinc-500">{gettext("Scripture text")}</p>
              <p class="mt-3 text-sm leading-relaxed text-zinc-700">
                {gettext(
                  "Full Bible text is not available in this version yet. Run mix scripture.import deuelbbk to import the Elberfelder translation, or use your own Bible for reading; use this page to log progress and keep notes."
                )}
              </p>
            </div>
          </div>

          <nav
            :if={@prev_chapter || @next_chapter}
            class="mt-6 flex items-center justify-between gap-4 border-t border-zinc-200 pt-4 text-sm"
          >
            <.link
              :if={@prev_chapter}
              navigate={
                ~p"/read/books/#{@prev_chapter.book.code}/#{@prev_chapter.chapter.chapter_number}"
              }
              class="text-primary hover:underline"
              aria-label={
                gettext("Previous chapter: %{book} %{number}",
                  book: @prev_chapter.book_name,
                  number: @prev_chapter.chapter.chapter_number
                )
              }
            >
              ← {@prev_chapter.book_name} {@prev_chapter.chapter.chapter_number}
            </.link>
            <span :if={is_nil(@prev_chapter)} class="flex-1" />
            <.link
              :if={@next_chapter}
              navigate={
                ~p"/read/books/#{@next_chapter.book.code}/#{@next_chapter.chapter.chapter_number}"
              }
              class="ml-auto text-primary hover:underline"
              aria-label={
                gettext("Next chapter: %{book} %{number}",
                  book: @next_chapter.book_name,
                  number: @next_chapter.chapter.chapter_number
                )
              }
            >
              {@next_chapter.book_name} {@next_chapter.chapter.chapter_number} →
            </.link>
          </nav>
        </div>

        <div class="mt-8 space-y-8 lg:mt-0">
          <section>
            <h2 class="mb-2 text-sm font-semibold uppercase tracking-wide text-zinc-500">
              {gettext("Notes")}
            </h2>
            <.form
              for={@note_form}
              id="chapter-note-form"
              phx-change="validate_note"
              phx-submit="save_note"
            >
              <.input
                field={@note_form[:body]}
                type="textarea"
                rows="6"
                placeholder={gettext("Write a note for this chapter...")}
                class="w-full rounded-lg border-zinc-200"
              />
              <div class="mt-2 flex items-center gap-3">
                <.button type="submit" class="bg-primary hover:bg-primary/90">
                  {gettext("Save note")}
                </.button>
                <span :if={@note_saved} class="text-sm text-emerald-700">{gettext("Saved")}</span>
              </div>
            </.form>
          </section>

          <section>
            <h2 class="mb-2 text-sm font-semibold uppercase tracking-wide text-zinc-500">
              {gettext("Reading history")}
            </h2>
            <ul
              :if={@history != []}
              class="rounded-xl border border-zinc-200 bg-card divide-y divide-zinc-100 text-sm shadow-sm"
            >
              <%= for event <- @history do %>
                <li class="px-4 py-2.5 text-zinc-700">
                  {RelativeTime.format_datetime(event.read_at, @timezone, @locale)}
                </li>
              <% end %>
            </ul>
            <p :if={@history == []} class="text-sm text-zinc-600">
              {gettext("No reads logged for this chapter yet.")}
            </p>
          </section>
        </div>
      </div>
    </div>
    """
  end

  @impl true
  def mount(%{"book_code" => book_code, "chapter" => chapter_str}, _session, socket) do
    user = Accounts.get_user!(socket.assigns.current_user.id)

    with {chapter_num, ""} <- Integer.parse(chapter_str),
         %{} = book <- Scripture.get_book_for_user(user, book_code),
         %{} = chapter <- Scripture.get_chapter_by_code_and_number(book_code, chapter_num),
         true <- chapter.book_id == book.id do
      {:ok, load_chapter(socket, user, book, chapter)}
    else
      _ ->
        {:ok,
         socket
         |> put_flash(:error, gettext("Chapter not found."))
         |> push_navigate(to: ~p"/read")}
    end
  end

  @impl true
  def handle_event("open_effective_date_picker", _params, socket) do
    {:noreply, EffectiveDateUI.open_picker(socket)}
  end

  def handle_event("close_effective_date_picker", _params, socket) do
    {:noreply, EffectiveDateUI.close_picker(socket)}
  end

  def handle_event("log_read", _params, socket) do
    user = Accounts.get_user!(socket.assigns.current_user.id)
    read_at = EffectiveDateUI.read_at_for_logging(user, socket.assigns.effective_date)

    case ReadingPlan.log_chapter_read(user, socket.assigns.chapter.id, read_at) do
      {:ok, _} ->
        {:noreply,
         socket
         |> put_flash(:chapter_read, Integer.to_string(socket.assigns.chapter.id))
         |> load_chapter(
           Accounts.get_user!(socket.assigns.current_user.id),
           socket.assigns.book,
           socket.assigns.chapter
         )
         |> assign(:note_saved, false)}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, gettext("Could not log read."))}
    end
  end

  def handle_event("undo_read", %{"chapter-id" => chapter_id_str}, socket) do
    user = Accounts.get_user!(socket.assigns.current_user.id)
    chapter = socket.assigns.chapter

    with {chapter_id, ""} <- Integer.parse(chapter_id_str),
         true <- chapter_id == chapter.id,
         {:ok, _} <- ReadingPlan.undo_last_chapter_read(user, chapter_id) do
      {:noreply,
       socket
       |> clear_flash(:chapter_read)
       |> load_chapter(Accounts.get_user!(user.id), socket.assigns.book, chapter)
       |> assign(:note_saved, false)}
    else
      _ ->
        {:noreply, put_flash(socket, :error, gettext("Could not undo read."))}
    end
  end

  def handle_event("validate_note", %{"note" => params}, socket) do
    form =
      %{"body" => params["body"] || ""}
      |> then(&to_form(&1, as: :note))

    {:noreply, assign(socket, :note_form, form)}
  end

  def handle_event("save_note", %{"note" => %{"body" => body}}, socket) do
    case Notes.upsert_note(socket.assigns.current_user, socket.assigns.chapter.id, body) do
      {:ok, _} ->
        {:noreply,
         socket
         |> put_flash(:info, gettext("Note saved."))
         |> assign(:note_saved, true)}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, gettext("Could not save note."))}
    end
  end

  defp load_chapter(socket, user, book, chapter) do
    locale = socket.assigns.locale
    book_name = Scripture.book_display_name(book, locale)
    timezone = user.timezone || "Etc/UTC"
    counts = ReadingPlan.read_counts_by_chapter_id(user.id)
    last_at = ReadingPlan.last_read_at_by_chapter_id(user.id)
    read_count = Map.get(counts, chapter.id, 0)
    last = Map.get(last_at, chapter.id)

    last_read_label =
      if read_count > 0,
        do:
          last
          |> ReadingPlan.relative_label(timezone)
          |> RelativeTimeFormat.format(locale),
        else: nil

    note = Notes.get_note(user.id, chapter.id)
    body = if note, do: note.body, else: ""

    history = ReadingPlan.read_events_for_chapter(user.id, chapter.id)

    translation = ScriptureText.get_default_translation()

    scripture_content =
      if translation do
        ScriptureText.get_chapter_content(translation, chapter.id)
      end

    prev_chapter =
      case Scripture.previous_chapter_for_user(user, book, chapter) do
        nil ->
          nil

        %{book: prev_book, chapter: prev} ->
          %{
            book: prev_book,
            chapter: prev,
            book_name: Scripture.book_display_name(prev_book, locale)
          }
      end

    next_chapter =
      case Scripture.next_chapter_for_user(user, book, chapter) do
        nil ->
          nil

        %{book: next_book, chapter: next} ->
          %{
            book: next_book,
            chapter: next,
            book_name: Scripture.book_display_name(next_book, locale)
          }
      end

    socket
    |> assign(:page_title, "#{book_name} #{chapter.chapter_number}")
    |> assign(:locale_return_to, ~p"/read/books/#{book.code}/#{chapter.chapter_number}")
    |> assign(:book, book)
    |> assign(:book_name, book_name)
    |> assign(:chapter, chapter)
    |> assign(:translation, translation)
    |> assign(:scripture_content, scripture_content)
    |> assign(:timezone, timezone)
    |> assign(:read_count, read_count)
    |> assign(:last_read_label, last_read_label)
    |> assign(:history, history)
    |> assign(:prev_chapter, prev_chapter)
    |> assign(:next_chapter, next_chapter)
    |> assign(:note_form, to_form(%{"body" => body}, as: :note))
    |> assign(:note_saved, false)
  end
end

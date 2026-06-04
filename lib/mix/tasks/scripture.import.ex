defmodule Mix.Tasks.Scripture.Import do
  @moduledoc """
  Imports Bible text from USFM into the database.

      mix scripture.import deuelbbk

  Expects `deuelbbk_usfm.zip` in the project root. Extracts to
  `priv/scripture/usfm/deuelbbk/` (gitignored) on first run.
  """
  use Mix.Task

  @shortdoc "Imports USFM Bible text (deuelbbk)"

  @impl Mix.Task
  def run([code]) do
    Mix.Task.run("app.start")

    source_dir =
      case code do
        "deuelbbk" -> BibleReader.ScriptureText.Importer.ensure_deuelbbk_extracted!()
        other -> Mix.raise("unsupported translation #{inspect(other)}")
      end

    IO.puts("Importing #{code} from #{source_dir}...")

    case BibleReader.ScriptureText.Importer.import_translation(code, source_dir) do
      {:ok, translation} ->
        IO.puts("Import complete: #{translation.name} (#{translation.code})")

      {:error, reason} ->
        Mix.raise("import failed: #{inspect(reason)}")
    end
  end

  def run(_args) do
    Mix.raise("usage: mix scripture.import deuelbbk")
  end
end

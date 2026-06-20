defmodule BibleReader.Scripture.Catalog do
  @moduledoc """
  Protestant 66-book canon plus a small **deuterocanonical / apocrypha** set for the
  “show apocrypha” preference. Chapter counts follow common Protestant and
  deuterocanonical chapter breaks used in English Bibles.
  """

  @type book_seed :: %{
          code: String.t(),
          name: String.t(),
          testament: :ot | :nt | :apocrypha,
          in_protestant_canon: boolean(),
          in_apocrypha: boolean(),
          chapter_count: pos_integer()
        }

  @doc """
  Returns book definitions in canonical reading order (OT, apocrypha, NT).
  """
  @spec books() :: [book_seed()]
  def books do
    protestant_ot() ++ apocrypha() ++ protestant_nt()
  end

  defp protestant_ot do
    [
      {"GEN", "Genesis", 50},
      {"EXO", "Exodus", 40},
      {"LEV", "Leviticus", 27},
      {"NUM", "Numbers", 36},
      {"DEU", "Deuteronomy", 34},
      {"JOS", "Joshua", 24},
      {"JDG", "Judges", 21},
      {"RUT", "Ruth", 4},
      {"1SA", "1 Samuel", 31},
      {"2SA", "2 Samuel", 24},
      {"1KI", "1 Kings", 22},
      {"2KI", "2 Kings", 25},
      {"1CH", "1 Chronicles", 29},
      {"2CH", "2 Chronicles", 36},
      {"EZR", "Ezra", 10},
      {"NEH", "Nehemiah", 13},
      {"EST", "Esther", 10},
      {"JOB", "Job", 42},
      {"PSA", "Psalms", 150},
      {"PRO", "Proverbs", 31},
      {"ECC", "Ecclesiastes", 12},
      {"SNG", "Song of Solomon", 8},
      {"ISA", "Isaiah", 66},
      {"JER", "Jeremiah", 52},
      {"LAM", "Lamentations", 5},
      {"EZK", "Ezekiel", 48},
      {"DAN", "Daniel", 12},
      {"HOS", "Hosea", 14},
      {"JOE", "Joel", 4},
      {"AMO", "Amos", 9},
      {"OBA", "Obadiah", 1},
      {"JON", "Jonah", 4},
      {"MIC", "Micah", 7},
      {"NAM", "Nahum", 3},
      {"HAB", "Habakkuk", 3},
      {"ZEP", "Zephaniah", 3},
      {"HAG", "Haggai", 2},
      {"ZEC", "Zechariah", 14},
      {"MAL", "Malachi", 4}
    ]
    |> Enum.map(fn {code, name, n} ->
      %{
        code: code,
        name: name,
        testament: :ot,
        in_protestant_canon: true,
        in_apocrypha: false,
        chapter_count: n
      }
    end)
  end

  defp apocrypha do
    [
      {"TOB", "Tobit", 14},
      {"JDT", "Judith", 16},
      {"WIS", "Wisdom", 19},
      {"SIR", "Sirach", 51},
      {"BAR", "Baruch", 6},
      {"1MA", "1 Maccabees", 16},
      {"2MA", "2 Maccabees", 15}
    ]
    |> Enum.map(fn {code, name, n} ->
      %{
        code: code,
        name: name,
        testament: :apocrypha,
        in_protestant_canon: false,
        in_apocrypha: true,
        chapter_count: n
      }
    end)
  end

  defp protestant_nt do
    [
      {"MAT", "Matthew", 28},
      {"MRK", "Mark", 16},
      {"LUK", "Luke", 24},
      {"JHN", "John", 21},
      {"ACT", "Acts", 28},
      {"ROM", "Romans", 16},
      {"1CO", "1 Corinthians", 16},
      {"2CO", "2 Corinthians", 13},
      {"GAL", "Galatians", 6},
      {"EPH", "Ephesians", 6},
      {"PHP", "Philippians", 4},
      {"COL", "Colossians", 4},
      {"1TH", "1 Thessalonians", 5},
      {"2TH", "2 Thessalonians", 3},
      {"1TI", "1 Timothy", 6},
      {"2TI", "2 Timothy", 4},
      {"TIT", "Titus", 3},
      {"PHM", "Philemon", 1},
      {"HEB", "Hebrews", 13},
      {"JAS", "James", 5},
      {"1PE", "1 Peter", 5},
      {"2PE", "2 Peter", 3},
      {"1JN", "1 John", 5},
      {"2JN", "2 John", 1},
      {"3JN", "3 John", 1},
      {"JUD", "Jude", 1},
      {"REV", "Revelation", 22}
    ]
    |> Enum.map(fn {code, name, n} ->
      %{
        code: code,
        name: name,
        testament: :nt,
        in_protestant_canon: true,
        in_apocrypha: false,
        chapter_count: n
      }
    end)
  end
end

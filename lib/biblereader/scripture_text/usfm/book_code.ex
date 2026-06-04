defmodule BibleReader.ScriptureText.Usfm.BookCode do
  @moduledoc """
  Maps USFM filename / \\id codes to stable catalog book codes.
  """

  @aliases %{
    "JOL" => "JOE"
  }

  @doc """
  Normalizes a USFM book code to the catalog `books.code` value.
  """
  @spec normalize(String.t()) :: String.t()
  def normalize(code) when is_binary(code) do
    code = String.upcase(code)
    Map.get(@aliases, code, code)
  end

  @doc """
  Extracts the book code from a USFM filename such as `02-GENdeuelbbk.usfm`.
  """
  @spec from_filename(String.t()) :: String.t() | nil
  def from_filename(filename) when is_binary(filename) do
    case Regex.run(~r/-([A-Z0-9]+)deuelbbk\.usfm$/i, filename) do
      [_, code] -> normalize(code)
      _ -> nil
    end
  end

  @doc """
  Extracts book code from the \\id line, e.g. `\\id GEN - Elberfelder...`.
  """
  @spec from_id_line(String.t()) :: String.t() | nil
  def from_id_line(line) when is_binary(line) do
    case Regex.run(~r/^\\id\s+([A-Z0-9]+)/i, String.trim(line)) do
      [_, code] -> normalize(code)
      _ -> nil
    end
  end
end

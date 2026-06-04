defmodule BibleReader.ScriptureText.Usfm.Tokenizer do
  @moduledoc false

  @doc """
  Tokenizes USFM into a flat list of `{:text, text}`, `{:open, marker, payload}`,
  and `{:close, marker}` tuples.
  """
  @spec tokenize(String.t()) :: [{atom(), String.t()} | {:open, String.t(), String.t()}]
  def tokenize(usfm) when is_binary(usfm) do
    usfm
    |> String.replace("\r\n", "\n")
    |> String.split("\\", trim: false)
    |> Enum.drop(1)
    |> Enum.flat_map(&segment_to_tokens/1)
  end

  defp segment_to_tokens(""), do: []

  defp segment_to_tokens(segment) do
    case Regex.run(~r/^([a-z0-9+]+)\*(.*)$/s, segment) do
      [_, marker, rest] ->
        [{:close, normalize_marker(marker)} | maybe_text(rest, [])]

      _ ->
        case Regex.run(~r/^([a-z0-9+*]+)\s*(.*)$/s, segment) do
          [_, marker, rest] ->
            [{:open, normalize_marker(marker), String.trim(rest)}]

          _ ->
            [{:text, String.trim(segment)}]
        end
    end
  end

  defp maybe_text("", acc), do: acc

  defp maybe_text(text, acc) do
    trimmed = String.trim(text)
    if trimmed == "", do: acc, else: [{:text, trimmed} | acc]
  end

  defp normalize_marker("+" <> rest), do: "+" <> String.downcase(rest)
  defp normalize_marker(marker), do: String.downcase(marker)
end

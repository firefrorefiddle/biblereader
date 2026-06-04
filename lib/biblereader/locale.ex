defmodule BibleReader.Locale do
  @moduledoc """
  Supported UI locales and helpers for resolving locale from HTTP headers or stored values.
  """

  @supported ~w(en de)
  @default "en"

  @doc "List of supported locale codes."
  @spec supported() :: [String.t()]
  def supported, do: @supported

  @doc "Default locale when none is set."
  @spec default() :: String.t()
  def default, do: @default

  @doc "Returns true if `locale` is a supported code."
  @spec supported?(String.t()) :: boolean()
  def supported?(locale) when locale in @supported, do: true
  def supported?(_), do: false

  @doc """
  Normalizes a locale string to a supported code, or returns `default/0`.
  """
  @spec normalize(String.t() | nil) :: String.t()
  def normalize(nil), do: @default
  def normalize(""), do: @default

  def normalize(locale) when is_binary(locale) do
    locale = String.downcase(locale)

    cond do
      locale in @supported -> locale
      String.starts_with?(locale, "de") -> "de"
      String.starts_with?(locale, "en") -> "en"
      true -> @default
    end
  end

  @doc """
  Picks a locale from the first `Accept-Language` header value.
  German (`de*`) maps to `de`; otherwise `en`.
  """
  @spec from_accept_language(String.t() | nil) :: String.t()
  def from_accept_language(nil), do: @default
  def from_accept_language(""), do: @default

  def from_accept_language(header) when is_binary(header) do
    header
    |> String.split(",", parts: 2)
    |> List.first()
    |> case do
      nil ->
        @default

      lang ->
        lang
        |> String.trim()
        |> String.split("-", parts: 2)
        |> hd()
        |> normalize()
    end
  end
end

defmodule BibleReader.Config do
  @moduledoc """
  Application-wide configuration helpers.

  Branding values such as `:app_name` are set in `config/config.exs` under
  `config :biblereader, ...` and read at runtime via `Application.get_env/2`.
  The app name is intentionally not translated.
  """

  @doc """
  Returns the configured product name (default `"BibleReader"`).

  Set via `config :biblereader, app_name: "..."` in `config/config.exs`.
  """
  @spec app_name() :: String.t()
  def app_name do
    Application.get_env(:biblereader, :app_name, "BibleReader")
  end
end

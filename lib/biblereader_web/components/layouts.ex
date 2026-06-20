defmodule BibleReaderWeb.Layouts do
  @moduledoc """
  This module holds different layouts used by your application.

  See the `layouts` directory for all templates available.
  The "root" layout is a skeleton rendered as part of the
  application router. The "app" layout is set as the default
  layout on both `use BibleReaderWeb, :controller` and
  `use BibleReaderWeb, :live_view`.
  """
  use BibleReaderWeb, :html

  embed_templates "layouts/*"

  @doc false
  def app_name, do: BibleReader.Config.app_name()

  @doc false
  def page_title_suffix, do: " · #{app_name()}"
end

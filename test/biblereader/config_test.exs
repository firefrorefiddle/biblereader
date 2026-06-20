defmodule BibleReader.ConfigTest do
  use ExUnit.Case, async: true

  alias BibleReader.Config

  test "app_name/0 returns configured branding" do
    assert Config.app_name() == Application.get_env(:biblereader, :app_name, "BibleReader")
    assert Config.app_name() == "BibleReader"
  end
end

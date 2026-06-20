defmodule BibleReader.Scripture.CatalogTest do
  use ExUnit.Case, async: true

  alias BibleReader.Scripture.Catalog

  test "Joel has four chapters (Elberfelder / deuelbbk split)" do
    joe = Enum.find(Catalog.books(), &(&1.code == "JOE"))
    assert joe.chapter_count == 4
  end
end

defmodule BibleReader.I18n.CalendarFormatTest do
  use ExUnit.Case, async: true

  alias BibleReader.I18n.CalendarFormat
  alias BibleReader.ReadingPlan.{EffectiveDate, RelativeTime}

  @june_sunday ~D[2024-06-16]

  describe "format_long/2" do
    test "German locale uses German month and weekday names" do
      label = CalendarFormat.format_long(@june_sunday, "de")

      assert label =~ "Juni"
      assert label =~ "Sonntag"
      refute label =~ "June"
      refute label =~ "Sunday"
    end

    test "English locale uses English month and weekday names" do
      label = CalendarFormat.format_long(@june_sunday, "en")

      assert label =~ "Jun"
      assert label =~ "Sunday"
      refute label =~ "Juni"
    end

    test "EffectiveDate.format_long delegates with German locale" do
      assert EffectiveDate.format_long(@june_sunday, "de") ==
               CalendarFormat.format_long(@june_sunday, "de")
    end
  end

  describe "format_datetime/2" do
    test "German locale uses numeric date without English month names" do
      dt = ~U[2024-06-16 14:30:00Z]

      label = CalendarFormat.format_datetime(dt, "de")

      assert label == "16.06.2024, 14:30"
      refute label =~ "June"
    end

    test "English locale uses abbreviated English month name" do
      dt = ~U[2024-06-16 14:30:00Z]

      label = CalendarFormat.format_datetime(dt, "en")

      assert label =~ "Jun 16, 2024"
      refute label =~ "Juni"
    end

    test "RelativeTime.format_datetime applies user timezone before formatting" do
      dt = ~U[2024-06-16 22:30:00Z]

      label = RelativeTime.format_datetime(dt, "America/New_York", "de")

      assert label == "16.06.2024, 18:30"
    end
  end
end

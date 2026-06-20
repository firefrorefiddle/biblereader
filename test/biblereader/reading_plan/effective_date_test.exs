defmodule BibleReader.ReadingPlan.EffectiveDateTest do
  use BibleReader.DataCase, async: true

  import BibleReader.AccountsFixtures

  alias BibleReader.ReadingPlan.EffectiveDate
  alias BibleReader.ReadingPlan.RelativeTime

  setup do
    %{user: user_fixture()}
  end

  test "validate accepts today and last 7 days", %{user: user} do
    today = RelativeTime.today_in_zone(user.timezone)
    earliest = Date.add(today, -6)

    assert {:ok, ^today} = EffectiveDate.validate(today, user.timezone)
    assert {:ok, ^earliest} = EffectiveDate.validate(earliest, user.timezone)
  end

  test "validate rejects future dates", %{user: user} do
    today = RelativeTime.today_in_zone(user.timezone)
    future = Date.add(today, 1)
    assert {:error, :future} = EffectiveDate.validate(future, user.timezone)
  end

  test "validate rejects dates older than 7 days", %{user: user} do
    today = RelativeTime.today_in_zone(user.timezone)
    too_old = Date.add(today, -7)
    assert {:error, :too_old} = EffectiveDate.validate(too_old, user.timezone)
  end

  test "validate_string rejects invalid input", %{user: user} do
    assert {:error, :invalid} = EffectiveDate.validate_string("not-a-date", user.timezone)
  end

  test "read_at_for past day uses noon in user timezone", %{user: user} do
    today = RelativeTime.today_in_zone(user.timezone)
    past = Date.add(today, -2)

    read_at = EffectiveDate.read_at_for(past, user.timezone)
    assert RelativeTime.date_in_zone(read_at, user.timezone) == past

    local =
      case DateTime.shift_zone(read_at, user.timezone, Tzdata.TimeZoneDatabase) do
        {:ok, dt} -> dt
        {:error, _} -> flunk("shift failed")
      end

    assert local.hour == 12
    assert local.minute == 0
  end

  test "read_at_for today returns current instant", %{user: user} do
    today = RelativeTime.today_in_zone(user.timezone)
    before = DateTime.utc_now()
    read_at = EffectiveDate.read_at_for(today, user.timezone)
    after_ = DateTime.utc_now()

    assert DateTime.compare(read_at, before) in [:eq, :gt]
    assert DateTime.compare(read_at, after_) in [:eq, :lt]
  end

  test "active? is false for nil or today", %{user: user} do
    today = RelativeTime.today_in_zone(user.timezone)
    refute EffectiveDate.active?(nil, user.timezone)
    refute EffectiveDate.active?(today, user.timezone)
  end

  test "active? is true for past days in window", %{user: user} do
    today = RelativeTime.today_in_zone(user.timezone)
    past = Date.add(today, -1)
    assert EffectiveDate.active?(past, user.timezone)
  end
end

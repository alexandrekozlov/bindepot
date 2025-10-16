defmodule Bindepot.TestHelpers do
  import ExUnit.Assertions

  def assert_within_seconds(dt1, dt2, max_diff_secs \\ 60) do
    diff = NaiveDateTime.diff(dt1, dt2, :second) |> abs()

    assert diff <= max_diff_secs,
           "Expected datetimes to be within #{max_diff_secs}s, got difference: #{diff}s"
  end
end

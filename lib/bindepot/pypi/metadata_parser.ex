defmodule Bindepot.Pypi.MetadataParser do
  def parse_metadata(metadata) do
    lines = String.split( metadata, ~r/\n(?![ \t])/)
    Enum.reduce(lines, [], fn l, acc ->
      [k, v] = String.split(l, ":", parts: 2) |> IO.inspect()
      validate_metadata_value(k, v)
      [ acc | {k, v} ]
    end)
  end

  defp validate_metadata_value(_k, _v) do

  end
end

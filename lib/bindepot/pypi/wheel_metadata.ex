defmodule Bindepot.PyPI.WheelMetadata do
  @doc ~S"""
  Extracts and returns package metadata from a PyPI wheel (.whl) file.

  Example:
  ```
    path = "/path/to/foo-1.2.3-py3-none-any.whl"

    case WheelMetadata.extract_wheel_metadata(path) do
      {:ok, meta} ->
        IO.inspect(meta, label: "Metadata")

      {:error, reason} ->
        IO.puts("Failed: #{inspect(reason)}")
    end
  ```

  Returns:
  ```
    %{
      "Name" => "requests",
      "Version" => "2.32.0",
      "Summary" => "Python HTTP library",
      "Requires-Dist" => [
        "charset-normalizer>=2,<4",
        "idna>=2.5,<4",
        "urllib3>=2,<3"
      ]
    }
  ```

  Returns:
      {:ok, metadata_map} on success
      {:error, reason} on failure
  """
  def extract_wheel_metadata(path) when is_binary(path) do
    case :zip.unzip(String.to_charlist(path), [:memory]) do
      {:ok, files} ->
        with {:ok, metadata_content} <- find_metadata_file(files),
             {:ok, parsed} <- parse_metadata(metadata_content) do
          {:ok, parsed}
        end

      {:error, reason} ->
        {:error, reason}
    end
  end

  # Find the *.dist-info/METADATA file inside wheel
  defp find_metadata_file(files) do
    case Enum.find(files, fn {name, _content} ->
           to_string(name) =~ ~r/\.dist-info\/METADATA$/
         end) do
      nil ->
        {:error, :metadata_not_found}

      {_name, content} ->
        {:ok, to_string(content)}
    end
  end

  # Parse RFC822-like METADATA into a map
  defp parse_metadata(content) when is_binary(content) do
    lines = String.split(content, ~r/\R/, trim: true)

    metadata =
      Enum.reduce(lines, %{}, fn line, acc ->
        case String.split(line, ":", parts: 2) do
          [key, value] ->
            key = String.trim(key)
            value = String.trim(value)

            Map.update(acc, key, value, fn
              existing when is_binary(existing) -> [existing, value]
              existing when is_list(existing) -> existing ++ [value]
            end)

          _ ->
            acc
        end
      end)

    {:ok, metadata}
  end
end

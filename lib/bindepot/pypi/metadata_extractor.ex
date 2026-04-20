defmodule Bindepot.Pypi.MetadataExtractor do
  def extract_wheel_metadata(zip_path) do
    with {:ok, files} <- :zip.list_dir(String.to_charlist(zip_path)) do
      files
      |> Enum.filter(&(elem(&1, 0) == :zip_file))
      |> Enum.map(&elem(&1, 1))
      |> Enum.find(&metadata_path?/1)
      |> case do
        nil ->
          {:error, :not_found}

        path ->
          extract_from_zip(zip_path, path)
      end
    end
  end

  def extract_source_metadata(tar_path) do
    tar_charlist = String.to_charlist(tar_path)

    with {:ok, files} <- :erl_tar.table(tar_charlist, [:compressed]) do
      files
      |> Enum.find(&metadata_path?/1)
      |> case do
        nil ->
          {:error, :not_found}

        path ->
          extract_from_tar(tar_charlist, path)
      end
    end
  end

  defp metadata_path?(path) do
    path
    |> to_string()
    |> String.split("/", trim: true)
    |> case do
      ["METADATA"] -> true
      ["PKG-INFO"] -> true
      [_dir, "METADATA"] -> true
      [_dir, "PKG-INFO"] -> true
      _ -> false
    end
  end

  defp extract_from_zip(zip_path, path) do
    case :zip.unzip(String.to_charlist(zip_path), [{:file_list, [path]}, :memory]) do
      {:ok, [{_filename, content}]} ->
        {:ok, to_string(content)}

      error ->
        error
    end
  end

  defp extract_from_tar(tar_path, path) do
    case :erl_tar.extract(
           tar_path,
           [:compressed, :memory, {:files, [path]}]
         ) do
      {:ok, [{_filename, content}]} ->
        {:ok, to_string(content)}

      error ->
        error
    end
  end
end

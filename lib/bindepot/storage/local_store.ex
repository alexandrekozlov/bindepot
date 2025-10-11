defmodule Bindepot.Storage.LocalStore do
  @behaviour Bindepot.Storage.Store
  require Logger

  def data_dir do
    Application.fetch_env!(:bindepot, :data_dir)
  end

  def cache_dir do
    Application.fetch_env!(:bindepot, :cache_dir)
  end

  def repo_path(id) when is_binary(id) do
    prefix = id |> String.replace("-", "") |> String.slice(0, 2)
    Path.join([data_dir(), prefix, id])
  end

  def create_repo_dir(id) when is_binary(id) do
    dir = repo_path(id)

    case File.mkdir_p(dir) do
      :ok -> :ok
      {:error, reason} -> {:error, reason}
    end
  end

  def delete_repo_dir(id) when is_binary(id) do
    dir = repo_path(id)

    case File.rm_rf(dir) do
      {:ok, _} -> :ok
      {:error, reason, file} -> {:error, reason, file}
    end
  end

  @doc """
    Move file from temp to final location on the same filesystem.
  """
  def upload_temp_to_final(temp_path, final_path) do
    case File.rename(temp_path, final_path) do
      :ok ->
        :ok

      {:error, _} = err ->
        # attempt copy+delete as fallback
        case File.cp(temp_path, final_path) do
          :ok ->
            File.rm(temp_path)
            :ok

          {:error, _reason} ->
            err
        end
    end
  end
end

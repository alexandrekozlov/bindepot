defmodule Bindepot.Storage.FilesystemStorage do
  defstruct [:id, :store_root_directory]

  @behaviour Bindepot.Storage.StorageAdapter
  require Logger
  alias Bindepot.Storage.FilesystemStorage

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

  def from_configuration(config) do
    %FilesystemStorage{
      store_root_directory: Map.fetch!(config, :store_root_directory)
    }
  end

  def create(%FilesystemStorage{store_root_directory: store_root_directory}) do
    store_id = UUID.uuid4()
    File.mkdir_p!(store_root_directory)
    File.write!(Path.join(store_root_directory, ".id"), store_id)
    {:ok, %FilesystemStorage{id: store_id, store_root_directory: store_root_directory}}
  end

  @impl Bindepot.Storage.StorageAdapter
  def put(
        %FilesystemStorage{store_root_directory: store_root_directory},
        file_path,
        id \\ UUID.uuid4()
      ) do
    rel_object_path = new_object(id)
    full_object_path = Path.join(store_root_directory, rel_object_path)
    File.mkdir_p!(Path.dirname(full_object_path))
    File.cp!(file_path, full_object_path)
    {:ok, rel_object_path}
  end

  @impl Bindepot.Storage.StorageAdapter
  def get(%FilesystemStorage{store_root_directory: store_root_directory}, rel_object_path) do
    full_path = Path.join(store_root_directory, rel_object_path)

    if File.exists?(full_path) do
      {:ok, full_path}
    else
      {:error, "file not found"}
    end
  end

  def new_object(id) do
    case id |> String.replace("-", "") |> String.slice(0, 2) do
      "" -> id
      partition -> Path.join(partition, id)
    end
  end
end

defmodule Bindepot.Core.Assets do
  import Ecto.Query, warn: false

  alias Bindepot.Core.Blobs
  alias Bindepot.Core.FileUtils
  alias Bindepot.Core.Node
  alias Bindepot.Core.Nodes
  alias Bindepot.Core.Repository

  require Logger

  @hashes [:md5, :sha, :sha256, :blake2b]

  def all(%Repository{} = repo) do
    Nodes.get_files(repo.id)
  end

  @doc ~S"""
    Puts file as an asset into repository.

    `path` is a the relaive path in the repository.

    `source_path` the file to be stored.

    Returns file node on success.

    In order to replace an existing file, set option `:replace` to true.

  """
  @spec put_file(any(), String.t(), String.t(), [{:replace, boolean()}]) ::
          {:ok, Node.t()} | {:error, [any()], nil}
  def put_file(repository_id, path, source_path, opts \\ []) do
    {:ok, _status, blob, _dest} = store_file(source_path)
    Nodes.create_file(repository_id, path, blob.id, opts)
  end

  def put_stream(repository_id, path, stream, opts \\ []) do
    {:ok, _status, blob, _dest} = store_stream(stream)
    Nodes.create_file(repository_id, path, blob.id, opts)
  end

  def get_file(repository_id, path, dest_file) do
    case get_stream(repository_id, path) do
      nil ->
        nil

      stream ->
        FileUtils.store(stream, dest_file)
    end
  end

  def get_stream(repository_id, path) do
    node = Nodes.get_file(repository_id, path)

    if is_nil(node) or node.type != :file do
      nil
    else
      blob = Blobs.get(node.blob_id)
      prefix = String.slice(blob.sha256, 0, 2)

      store_path()
      |> Path.join(prefix)
      |> Path.join(blob.sha256)
      |> File.stream!(4096)
    end
  end

  defp store_file(file_path) do
    # We already have a file, just need to compute hash and copy/move it
    file_path
    |> File.stream!(4096)
    |> FileUtils.hash(@hashes)
    |> then(&store_blob(file_path, &1))
  end

  defp store_stream(stream) do
    temp_dir = Path.join(store_path(), "temp")
    File.mkdir_p!(temp_dir)

    temp_file = Path.join(temp_dir, UUID.uuid4())
    hashes = FileUtils.hash_and_store(stream, @hashes, temp_file)

    store_blob(temp_file, hashes)
  end

  defp store_blob(source_file, hashes) do
    %{size: file_size} = File.stat!(source_file)
    sha256 = Map.get(hashes, :sha256)

    blob =
      %{
        size: file_size,
        md5: Map.get(hashes, :md5),
        sha1: Map.get(hashes, :sha),
        sha256: sha256,
        blake2: Map.get(hashes, :blake2b)
      }
      |> Blobs.put()

    prefix = String.slice(sha256, 0, 2)
    dest_dir = Path.join(store_path(), prefix)
    dest_file = Path.join(dest_dir, sha256)

    case blob do
      # New blob - ok to replace file
      {:ok, blob_struct, :new} ->
        with :ok <- File.mkdir_p!(dest_dir),
             :ok <- FileUtils.move_file(source_file, dest_file) do
          {:ok, :new, blob_struct, dest_file}
        else
          {:error, reason} ->
            {:error, reason}
        end

      # Existing blob - no need to replace the file
      {:ok, blob_struct, :existing} ->
        {:ok, :existing, blob_struct, dest_file}

      # Conflict or error - do not replace. abort.
      {:error, _} ->
        {:error, "failed to store BLOB"}
    end
  end

  defp store_path() do
    Application.get_env(:bindepot, :data_dir)
  end
end

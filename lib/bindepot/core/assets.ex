defmodule Bindepot.Core.Assets do
  import Ecto.Query, warn: false

  alias Bindepot.Core.Node
  alias Bindepot.Core.Nodes
  alias Bindepot.Core.Blobs
  alias Bindepot.Core.Repository
  alias Bindepot.Core.Hasher

  require Logger

  def all(%Repository{} = repo) do
    Nodes.get_files(repo.id)
  end

  @doc ~S"""
    Puts file as an asset into repository.

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

  def get_stream(repository_id, path) do
    node = Nodes.get_file(repository_id, path)

    if is_nil(node) or node.type != 1 do
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
    hashes =
      File.stream!(file_path, 4096)
      |> compute_hash()

    store_blob(file_path, hashes)
  end

  defp store_stream(stream) do
    temp_dir = Path.join(store_path(), "temp")
    File.mkdir_p!(temp_dir)

    temp_file = Path.join(temp_dir, UUID.uuid4())
    hashes = write_file(stream, temp_file)

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
             :ok <- move_file(source_file, dest_file) do
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

  # Moves file by either renaming if source and destination are on the same
  # filesystem or copy/delete if on different filesystems.
  # Both source and destination are file names.
  @spec move_file(String.t(), String.t()) :: :ok | {:error, File.posix()}
  defp move_file(src, dst) do
    case is_same_fs(src, dst) do
      # both locations are on the same filesystem, can move
      true ->
        File.rename(src, dst)

      # source and destination on different filesystems. copy/delete
      false ->
        with :ok <- File.cp(src, dst) do
          # ignore result as we only care that file ended up where we wanted.
          File.rm(src)
          :ok
        else
          {:error, posix} ->
            {:error, posix}
        end

      {:error, posix} ->
        {:error, posix}
    end
  end

  defp is_same_fs(src, dst) do
    with {:ok, s_stat} <- File.stat(src),
         {:ok, d_stat} <- File.stat(Path.dirname(dst)) do
      s_stat.major_device == s_stat.minor_device and
        d_stat.major_device == d_stat.minor_device
    else
      {:error, posix} ->
        {:error, posix}
    end
  end

  defp write_file(stream, file_path) do
    {:ok, res} = File.open(file_path, [:write, :binary], &compute_hash(stream, &1))
    res
  end

  defp compute_hash(stream, io \\ nil) do
    hashes =
      stream
      |> Enum.reduce(
        Hasher.hash_init([:md5, :sha, :sha256, :blake2b]),
        &hashing_reducer(&1, &2, io)
      )
      |> Hasher.hash_final()

    Hasher.to_string(hashes)
  end

  defp hashing_reducer(chunk, hash_state, io) do
    io && IO.binwrite(io, chunk)
    Hasher.hash_update(hash_state, chunk)
  end

  defp store_path() do
    Application.get_env(:bindepot, :data_dir)
  end
end

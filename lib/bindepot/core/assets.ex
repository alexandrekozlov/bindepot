defmodule Bindepot.Core.Assets do
  import Ecto.Query, warn: false

  alias Bindepot.Repo
  alias Bindepot.Core.Nodes
  alias Bindepot.Core.Blobs
  alias Bindepot.Core.Repository
  alias Bindepot.Core.Hasher

  require Logger

  def all(%Repository{} = repo) do
    Nodes.get_files(repo.id)
  end

  def put(repository_id, path, source_path) when is_binary(source_path) do
    {:ok, _status, blob, _dest} = store_file(source_path)
    Nodes.create_file(repository_id, path, blob.id)
  end

  def put_stream(repository_id, path, stream) do
    {:ok, _status, blob, _dest} = store_stream(stream)
    Nodes.create_file(repository_id, path, blob.id)
  end

  def get(repository_id, path) do
    p = Path.dirname(path)
    n = Path.basename(path)
    node = Repo.get_by(Node, repository_id: repository_id, path: p, name: n, type: 1)
    blob = Repo.get(Blob, node.blob_id)
    prefix = String.slice(blob.sha256, 0, 2)
    {:ok, store_path() |> Path.join(prefix) |> Path.join(blob.sha256)}
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
        File.mkdir_p!(dest_dir)
        # TODO: rename breaks tests as it deletes the test input file,
        # but this is fixable.
        # File.rename!(source_file, dest_file)
        File.cp!(source_file, dest_file)
        {:ok, :new, blob_struct, dest_file}

      # Existing blob - no need to replace the file
      {:ok, blob_struct, :existing} ->
        # TODO: At least stat the file to see that it is still there and of expected size
        {:ok, :existing, blob_struct, dest_file}

      # Conflict or error - do not replace. abort.
      {:error, _, _} ->
        # TODO: Clean up the temp file
        {:error, "failed to store BLOB"}
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

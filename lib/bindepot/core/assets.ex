defmodule Bindepot.Core.Assets do
  import Ecto.Query, warn: false

  alias Bindepot.Core.Blob
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

    Options:

    `:replace` - when `true`, replaces an existing asset (defaults to `false`)

    `:properties` - free form string attached to the asset.

    `:keep_source` - when `true`, do not delete source file (defaults to `false`)

  """
  @spec put_file(any(), String.t(), String.t(),
          replace: boolean(),
          properties: String.t(),
          keep_source: boolean()
        ) :: {:ok, Node.t()} | {:error, [any()], nil}
  def put_file(repository_id, path, source_path, opts \\ []) do
    keep_source = Keyword.get(opts, :keep_source, false)

    {:ok, _status, blob, _dest} = store_file(source_path, keep_source)
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
    repository_id
    |> Nodes.get_file(path)
    |> do_get_stream_from_node()
  end

  defp do_get_stream_from_node(nil) do
    nil
  end

  defp do_get_stream_from_node(%Node{type: :file, blob_id: blob_id}) do
    with %Blob{sha256: sha256} <- Blobs.get(blob_id) do
      Blobs.get_blob_path(sha256)
    else
      _ ->
        nil
    end
  end

  defp store_file(file_path, keep_source) when is_boolean(keep_source) do
    # We already have a file, just need to compute hash and copy/move it
    file_path
    |> File.stream!(4096)
    |> FileUtils.hash(@hashes)
    |> then(&Blobs.store(file_path, &1, copy: keep_source))
  end

  defp store_stream(stream) do
    temp_file =
      store_path()
      |> Path.join("temp")
      |> tap(&File.mkdir_p!(&1))
      |> Path.join(UUID.uuid4())

    {:ok, hashes} = FileUtils.hash_and_store(stream, @hashes, temp_file)

    Blobs.store(temp_file, hashes)
  end

  defp store_path() do
    Application.get_env(:bindepot, :data_dir)
  end
end

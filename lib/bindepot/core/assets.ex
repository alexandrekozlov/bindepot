defmodule Bindepot.Core.Assets do
  import Ecto.Query, warn: false

  alias Bindepot.Core.Repositories
  alias Bindepot.Repo
  alias Bindepot.Core.Asset
  alias Bindepot.Core.Repository
  alias Bindepot.Core.Hasher

  require Logger

  def all() do
    Repo.all(from a in Asset, preload: :repository)
  end

  def all(%Repository{} = repo) do
    Repo.all(from a in Asset, where: a.repository_id == ^repo.id, preload: :repository)
  end

  def put(repository_id, name, path, source_path) when is_binary(source_path) do
    id = UUID.uuid4()
    {:ok, _status, _dest_file, size, hashes} = store_file(source_path)

    repository = Repositories.get(repository_id)

    changeset =
      Ecto.build_assoc(repository, :assets)
      |> Asset.changeset(%{
        id: id,
        name: name,
        path: path,
        size: size,
        md5: Map.get(hashes, :md5),
        sha1: Map.get(hashes, :sha),
        sha256: Map.get(hashes, :sha256)
      })

    Repo.insert(changeset,
      on_conflict: [set: [name: name]],
      conflict_target: :name
    )
  end

  def put(repository_id, name, path, stream) do
    id = UUID.uuid4()
    {:ok, _status, _dest_file, size, hashes} = store_stream(stream, id)

    repository = Repositories.get(repository_id)

    changeset =
      Ecto.build_assoc(repository, :assets)
      |> Asset.changeset(%{
        id: id,
        name: name,
        path: path,
        size: size,
        md5: Map.get(hashes, :md5),
        sha1: Map.get(hashes, :sha),
        sha256: Map.get(hashes, :sha256)
      })

    Repo.insert(changeset,
      on_conflict: [set: [name: name]],
      conflict_target: :name
    )
  end

  def get(%Asset{} = asset) do
    ass = Repo.preload(asset, [:repository])
    prefix = String.slice(ass.sha256, 0, 2)
    {:ok, store_path() |> Path.join(prefix) |> Path.join(ass.sha256)}
  end

  def get(%Ecto.Query{} = q) do
    asset = Repo.one!(q)
    ass = Repo.preload(asset, [:repository])
    prefix = String.slice(ass.sha256, 0, 2)
    {:ok, store_path() |> Path.join(prefix) |> Path.join(ass.sha256)}
  end

  defp store_file(file_path) do
    # We already have a file, just need to compute hash and copy/move it
    hashes =
      File.stream!(file_path, 4096)
      |> compute_hash()

    store_file(file_path, hashes)
  end

  defp store_stream(stream, id) do
    temp_dir = Path.join(store_path(), "temp")
    File.mkdir_p!(temp_dir)

    temp_file = Path.join(temp_dir, id)
    hashes = write_file(stream, temp_file)

    store_file(temp_file, hashes)
  end

  defp store_file(source_file, hashes) do
    sha256 = Map.get(hashes, :sha256)
    prefix = String.slice(sha256, 0, 2)

    dest_dir = Path.join(store_path(), prefix)
    File.mkdir_p!(dest_dir)

    dest_file = Path.join(dest_dir, sha256)

    status =
      if File.exists?(dest_file) do
        :exists
      else
        # File.rename!(source_file, dest_file)
        File.cp!(source_file, dest_file)
        :new
      end

    %{size: size} = File.stat!(dest_file)

    {:ok, status, dest_file, size, hashes}
  end

  defp write_file(stream, file_path) do
    File.open(file_path, [:write, :binary], &compute_hash(stream, &1))
  end

  defp compute_hash(stream, io \\ nil) do
    hashes =
      stream
      |> Enum.reduce(Hasher.hash_init([:md5, :sha, :sha256]), &hashing_reducer(&1, &2, io))
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

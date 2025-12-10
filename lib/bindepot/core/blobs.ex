defmodule Bindepot.Core.Blobs do
  import Ecto.Query, warn: false
  alias Bindepot.Core.FileUtils
  alias Ecto.Changeset

  alias Bindepot.Repo
  alias Bindepot.Core.Blob

  def all() do
    Repo.all(Blob)
  end

  @doc ~S"""
    Gets BLOB by ID.
  """
  @spec get(String.t() | any()) :: Blob.t() | nil
  def get(id) do
    Repo.get(Blob, id)
  end

  @doc ~S"""
    Gets BLOB by hash.
  """
  @spec get_by_sha256(String.t()) :: Blob.t() | nil
  def get_by_sha256(hash) do
    Blob.all()
    |> Blob.by_sha256(hash)
    |> Repo.one()
  end

  @doc ~S"""
    Creates new BLOB metadata or updates existing one.

    BLOBs are uniquely identified by SHA-256 hash or their ID.
    SHA-256 and size are required when putting a BLOB, while other hashes are
    optional. Once hash value is set, it becomes immutable.

    On success, returns struct and whether a new BLOB was created or an existing
    one updated.

  """
  @spec put(map()) :: {:ok, Blob.t(), :existing | :new} | {:error, any()}
  def put(blob) when is_map(blob) do
    new =
      %Blob{}
      |> Blob.changeset(blob)

    sha256 = Changeset.fetch_field!(new, :sha256)

    case Repo.one(from b in Blob, where: b.sha256 == ^sha256) do
      nil ->
        new
        |> Repo.insert()
        |> parse_status(:new)

      existing_blob ->
        existing_blob
        |> Blob.changeset(blob)
        |> Repo.update()
        |> parse_status(:existing)
    end
  end

  @type hashes :: %{required(:sha256) => String.t(), optional(atom) => String.t()}

  @doc """
    Store file as BLOB.

    `hashes` is a map of hash algorithm and hash value.

    The keys correspond to hashing algorithms supported by `:crypto`. This
    function looks for the following keys:
     * `:md5` - MD5
     * `:sha` - SHA-1
     * `:sha256` - SHA-256
     * `:blake2b` - BLAKE2b

     All keys are optional except for `:sha256`.

    Options:

    `:copy` - when `true`, do not delete source file (defaults to `false`).

  """
  @spec store(String.t(), hashes(), copy: boolean()) ::
          {:error, any()} | {:ok, :existing | :new, Bindepot.Core.Blob.t(), binary()}
  def store(source_file, hashes = %{}, opts \\ []) do
    do_copy? =
      opts
      |> Keyword.validate!(copy: false)
      |> Keyword.fetch!(:copy)

    %{size: file_size} = File.stat!(source_file)
    sha256 = Map.fetch!(hashes, :sha256)
    dest_file = get_blob_path(sha256)

    %{
      size: file_size,
      md5: Map.get(hashes, :md5),
      sha1: Map.get(hashes, :sha),
      sha256: sha256,
      blake2: Map.get(hashes, :blake2b)
    }
    |> put()
    |> do_create_blob(source_file, dest_file, do_copy?)
  end

  @doc """
    Given BLOB identity, returns absolute path to the BLOB.

    `blob_identity` is an arbitrary string, but typical BLOB's hash.
  """
  def get_blob_path(blob_identity) do
    Path.join([
      store_path(),
      String.slice(blob_identity, 0, 2),
      blob_identity
    ])
  end

  defp do_create_blob({:ok, blob_struct, :new}, src, dst, true = _is_copy) do
    with :ok <- File.mkdir_p(Path.dirname(dst)),
         :ok <- File.cp(src, dst) do
      {:ok, :new, blob_struct, dst}
    else
      {:error, reason} -> {:error, reason}
    end
  end

  defp do_create_blob({:ok, blob_struct, :new}, src, dst, false = _is_copy) do
    with :ok <- FileUtils.move_file(src, dst) do
      {:ok, :new, blob_struct, dst}
    else
      {:error, reason} -> {:error, reason}
    end
  end

  defp do_create_blob({:ok, blob_struct, :existing}, _src, dst, _is_copy) do
    {:ok, :existing, blob_struct, dst}
  end

  defp do_create_blob({:error, reason}, _src, _dst, _is_copy) do
    {:error, reason}
  end

  defp store_path() do
    Application.get_env(:bindepot, :data_dir)
  end

  defp parse_status(status, disposition) do
    case status do
      {:ok, schema} -> {:ok, schema, disposition}
      {:error, changeset} -> {:error, changeset}
    end
  end
end

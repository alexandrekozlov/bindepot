defmodule Bindepot.Core.Blobs do
  import Ecto.Query, warn: false
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

  defp parse_status(status, disposition) do
    case status do
      {:ok, schema} -> {:ok, schema, disposition}
      {:error, changeset} -> {:error, changeset}
    end
  end
end

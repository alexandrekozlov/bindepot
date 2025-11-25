defmodule Bindepot.Core.Blobs do
  import Ecto.Query, warn: false
  alias Ecto.Changeset

  alias Bindepot.Repo
  alias Bindepot.Core.Blob

  def all() do
    Repo.all(Blob)
  end

  def get(id) do
    Repo.get(Blob, id)
  end

  def get_by_sha256(hash) do
    Blob.all()
    |> Blob.by_sha256(hash)
    |> Repo.one()
  end

  def put(blob) when is_map(blob) do
    new =
      %Blob{}
      |> Blob.changeset(blob)

    sha256 = Changeset.fetch_field!(new, :sha256)

    case Repo.one(from b in Blob, where: b.sha256 == ^sha256) do
      nil ->
        Repo.insert(new)

      existing_blob ->
        Blob.changeset(existing_blob, blob)
        |> Repo.update()
    end
  end
end

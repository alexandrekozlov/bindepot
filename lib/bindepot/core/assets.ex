defmodule Bindepot.Core.Assets do
  import Ecto.Query, warn: false

  alias Bindepot.Repo
  alias Bindepot.Core.Asset
  alias Bindepot.Core.Repository
  alias Bindepot.Core.Filestores

  require Logger

  def all() do
    Repo.all(from a in Asset, preload: :repository)
  end

  def all(%Repository{} = repo) do
    Repo.all(from a in Asset, where: a.repository_id == ^repo.id, preload: :repository)
  end

  def put(%Repository{} = repo, name, source_path) do
    id = UUID.uuid4()

    store = Filestores.default()
    {:ok, file} = Filestores.store(store, source_path, id)

    changeset =
      Asset.changeset(%Asset{}, %{
        id: id,
        name: name,
        store_path: file,
        filestore_name: nil
      })
      # Cannot use put_assoc, since default store is never persisted.
      # For now it is set to nil, which implies a default store.
      # |> Ecto.Changeset.put_assoc(:filestore, store)
      |> Ecto.Changeset.put_assoc(:repository, repo)

    # TODO: This is effectively an UPSERT. However, this does not work coorectly
    # as we need to delete the previous artifact from storage.
    Repo.insert(changeset,
      on_conflict: [set: [name: name]],
      conflict_target: :name
    )
  end

  def get(%Asset{} = asset) do
    ass = Repo.preload(asset, [:repository, :filestore])
    Filestores.retrieve(ass.filestore, ass.store_path)
  end

  def get(%Ecto.Query{} = q) do
    asset = Repo.one!(q)
    ass = Repo.preload(asset, [:repository, :filestore])
    Filestores.retrieve(ass.filestore, ass.store_path)
  end
end

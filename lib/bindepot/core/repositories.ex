defmodule Bindepot.Core.Repositories do
  @moduledoc """
  Repository management: create, soft-delete, get, list.

  Uses a storage backend implementing `Bindepot.Storage.Filestore` (configurable).
  """

  import Ecto.Query, warn: false

  alias Bindepot.Core.Repositories
  alias Bindepot.Repo
  alias Bindepot.Core.Repository

  require Logger

  def all() do
    Repository.all()
    |> Repository.existing()
    |> Repo.all()
  end

  def all_deleted() do
    Repository.deleted()
    |> Repo.all()
  end

  def all_of_package_type(package_type) do
    Repository.all()
    |> Repository.existing()
    |> Repository.by_package_type(package_type)
    |> Repo.all()
  end

  def get(id) do
    Repo.get(Repository, id)
  end

  def get_deleted(id) do
    Repository.deleted()
    |> Repo.get(id)
  end

  def get_by_name(name) do
    Repository.all()
    |> Repository.existing()
    |> Repository.by_name(name)
    |> Repo.one()
  end

  def create(params) do
    %Repository{}
    |> Repository.create_changeset(params)
    |> Repo.insert()
  end

  def update(%Repository{} = repository, params) do
    repository
    |> Repository.update_changeset(params)
    |> Repo.update()
  end

  def delete(id) do
    repository = Repositories.get(id)

    deleted_name = "$deleted_#{repository.name}_#{repository.id}"

    now = NaiveDateTime.utc_now(:microsecond) |> NaiveDateTime.truncate(:second)

    repository
    |> Repository.delete_changeset(%{name: deleted_name, deleted_at: now})
    |> Repo.update()
  end

  def purge(id) do
    repository = Repositories.get_deleted(id)
    repository && Repo.delete(repository)
  end
end

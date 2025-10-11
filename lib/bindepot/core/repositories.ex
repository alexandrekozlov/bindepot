defmodule Bindepot.Core.Repositories do
  @moduledoc """
  Repository management: create, soft-delete, get, list.

  Uses a storage backend implementing `Bindepot.Storage.Store` (configurable).
  """

  import Ecto.Query, warn: false

  alias Bindepot.Repo
  alias Bindepot.Core.Repository

  require Logger

  @doc """
    Returns repositories.

    ## Options
      * `:include_deleted` - also include soft-deleted repositories.
      * `:package_type` - include only specific package type
  """
  def all(options \\ []) do
    include_deleted = Keyword.get(options, :include_deleted, false)
    package_type = Keyword.get(options, :package_type, nil)

    base =
      from r in Repository,
        order_by: [asc: r.name]

    query =
      if include_deleted do
        base
      else
        from r in base, where: is_nil(r.deleted_at)
      end

    filter =
      if is_nil(package_type) do
        query
      else
        from r in query, where: r.package_type == ^package_type
      end

    Repo.all(filter)
  end

  def deleted() do
    Repo.all(Repository.deleted())
  end

  def deleted?(%Repository{} = repository) do
    repository.deleted_at != nil
  end

  @doc """
    Get repository by ID.

    ## Options
      * `:allow_deleted` - allow to retrieve a soft-deleted repository.
  """
  def get(id, options \\ []) do
    options
    |> get_query()
    |> Repo.get(id)
  end

  @doc """
    Get repository by name.

    ## Options
      * `:allow_deleted` - allow to retrieve a soft-deleted repository.
  """
  def get_by_name(name, options \\ []) do
    options
    |> get_query()
    |> Repo.get_by(name: name)
  end

  def create(params) do
    changeset = Repository.changeset(%Repository{}, params)

    case Repo.insert(changeset) do
      {:ok, repository} ->
        case store().create_repo_dir(repository.id) do
          :ok ->
            {:ok, repository}

          {:error, reason} ->
            {:error, reason}
        end

      {:error, changeset} ->
        {:error, changeset}
    end
  end

  def change(repo, params) do
    repo
    |> Repository.change(:edit, params)
    |> Repo.update()
  end

  def delete(%Repository{id: id} = repository) do
    Logger.info("Deleting repository '#{repository.name}'")

    with repo <- get(id) do
      now = NaiveDateTime.utc_now(:microsecond) |> NaiveDateTime.truncate(:second)

      repo
      |> Ecto.Changeset.change(deleted_at: now)
      |> Repo.update()
    end
  end

  def purge(%Repository{id: id}, opts \\ []) do
    require_soft_deleted = Keyword.get(opts, :require_soft_deleted, true)

    # FIXME: It is a mess here, clean up and prettify.
    case get(id, allow_deleted: true) do
      repository ->
        if require_soft_deleted and is_nil(repository.deleted_at) do
          {:error, :not_soft_deleted}
        else
          # Step 1: remove filesystem (best-effort early fail)
          case store().delete_repo_dir(repository.id) do
            :ok ->
              # Step 2: remove DB rows in transaction (cascades will clear package rows)
              case Repo.delete(repository) do
                {:ok, %{} = _} ->
                  {:ok, :deleted}

                {:error, reason} ->
                  # DB delete failed even though FS was removed — log and return error
                  Logger.error(
                    "DB delete failed when hard-deleting repo #{repository.id}: #{Kernel.inspect(reason)}"
                  )

                  {:error, {:db_delete_failed, reason}}

                other ->
                  # Unexpected return shape
                  Logger.error(
                    "Unexpected Repo.transaction result when hard-deleting repo #{repository.id}: #{Kernel.inspect(other)}"
                  )

                  {:error, {:unexpected, other}}
              end

            {:error, reason, _file} ->
              Logger.error(
                "Failed to remove repo dir for hard-delete #{repository.id}: #{Kernel.inspect(reason)}"
              )

              {:error, {:rm_failed, reason}}

            # Some store implementations may return other truthy values; treat them as success
            other ->
              Logger.debug(
                "store().delete_repo_dir returned: #{Kernel.inspect(other)}; proceeding to DB delete"
              )

              case Repo.delete!(repository) do
                {:ok, %{} = _} ->
                  {:ok, :deleted}

                {:error, reason} ->
                  Logger.error(
                    "DB delete failed when hard-deleting repo #{repository.id}: #{Kernel.inspect(reason)}"
                  )

                  {:error, {:db_delete_failed, reason}}

                other2 ->
                  Logger.error(
                    "Unexpected Repo.transaction result when hard-deleting repo #{repository.id}: #{Kernel.inspect(other2)}"
                  )

                  {:error, {:unexpected, other2}}
              end
          end
        end

      nil ->
        {:error, :not_found}
    end
  end

  defp get_query(options) do
    allow_deleted = Keyword.get(options, :allow_deleted, false)

    if allow_deleted do
      Repository
    else
      from r in Repository, where: is_nil(r.deleted_at)
    end
  end

  defp store, do: Application.get_env(:bindepot, :store, Bindepot.Storage.LocalStore)
end

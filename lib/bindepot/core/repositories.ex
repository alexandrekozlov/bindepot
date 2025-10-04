defmodule Bindepot.Core.Repositories do
  @moduledoc """
  Repository management: create, soft-delete, get, list.

  Uses a storage backend implementing `Bindepot.Storage.Store` (configurable).
  """

  import Ecto.Query, warn: false
  alias Bindepot.Repo
  alias Bindepot.Core.Repository

  require Logger

  defp store, do: Application.get_env(:bindepot, :store, Bindepot.Storage.LocalStore)

  @doc """
  Compute repo path using the current store.
  """
  def repo_path(id), do: store().repo_path(id)

  @doc """
  Create repository (soft-delete not set). This will:
    - ensure filesystem dir exists
    - insert repository row and package-specific row inside one DB transaction
  If DB insert fails we remove the dir as a compensating action.
  """
  def create_repository(attrs) when is_map(attrs) do
    desired_id = Map.get(attrs, "id") || Map.get(attrs, :id)
    id_for_path =
      case desired_id do
        id when is_binary(id) -> id
        _ -> Ecto.UUID.generate()
      end

    try do
      # create FS dir first (fail early)
      case store().create_repo_dir(id_for_path) do
        :ok ->
          # ensure we pass the same id to DB insert so path and DB are in sync
          attrs_with_id =
            case desired_id do
              id when is_binary(id) -> Map.put(attrs, "id", id)
              _ -> Map.put(attrs, "id", id_for_path)
            end

          Repo.transaction(fn ->
            # Insert repository
            changeset = Repository.changeset(%Repository{}, attrs_with_id)
            Repo.insert!(changeset)
          end)
          |> case do
            {:ok, repo} -> {:ok, repo}
            {:error, reason} ->
              # cleanup dir - compensating action
              _ = store().delete_repo_dir(id_for_path)
              {:error, reason}
          end

        {:error, reason} ->
          {:error, {:mkdir_failed, reason}}
      end
    rescue
      e ->
        # Ensure we attempt to clean up if something crashes
        _ = store().delete_repo_dir(id_for_path)
        reraise e, __STACKTRACE__
    end
  end

  @doc """
  Soft-delete repository (set `deleted_at`) by id or name.
  Attempts to remove on-disk directory but will not fail if FS removal fails.
  """
  def delete_repository(id_or_name) when is_binary(id_or_name) do
    with {:ok, repo} <- fetch_by_id_or_name(id_or_name) do
      now = NaiveDateTime.utc_now() |> NaiveDateTime.truncate(:second)
      changeset = Ecto.Changeset.change(repo, deleted_at: now)

      case Repo.update(changeset) do
        {:ok, updated} ->
          # Attempt to remove directory; do not treat failure as hard error.
          case store().delete_repo_dir(updated.id) do
            :ok ->
              {:ok, updated}

            {:error, reason} ->
              Logger.error("Failed to remove repository dir for #{updated.id}: #{inspect(reason)}")
              {:ok, updated}
          end

        {:error, reason} ->
          {:error, reason}
      end
    else
      {:error, :not_found} -> {:error, :not_found}
    end
  end

  @doc """
  Hard-delete (purge) a repository and its package-specific rows and remove on-disk data.

  Signature:
    hard_delete_repository(id_or_name, opts \\ [])

  Options:
    * :require_soft_deleted (boolean) - if `true` (default) the repo must already have `deleted_at` set,
      otherwise function returns `{:error, :not_soft_deleted}`. Set to `false` if you want to force immediate purge.

  Behavior:
    1. Look up repository by id or name.
    2. If `:require_soft_deleted` and repo.deleted_at is nil -> return error.
    3. Try to remove the repository directory from the storage backend first.
      - If directory removal fails, return `{:error, {:rm_failed, reason}}` and **do not** touch DB.
    4. If storage removal succeeded, delete DB rows inside a DB transaction (Repo.delete!/1).
      Package-specific rows are cascaded by DB foreign key (on_delete: :delete_all).
    5. Returns `{:ok, :deleted}` or `{:error, reason}`.

  Notes:
    * Choosing to remove filesystem first ensures we avoid orphan files in the more-common case of FS problems.
    * There are still rare failure modes (e.g. FS removal succeeds, DB delete fails). In that case the files are gone but DB still exists —
      that is generally preferable to leaving files orphaned in storage.
  """
  def hard_delete_repository(id_or_name, opts \\ []) when is_binary(id_or_name) do
    require_soft_deleted = Keyword.get(opts, :require_soft_deleted, true)

    with {:ok, repo} <- fetch_by_id_or_name(id_or_name) do
      if require_soft_deleted and is_nil(repo.deleted_at) do
        {:error, :not_soft_deleted}
      else
        # Step 1: remove filesystem (best-effort early fail)
        case store().delete_repo_dir(repo.id) do
          :ok ->
            # Step 2: remove DB rows in transaction (cascades will clear package rows)
            case Repo.transaction(fn ->
                  Repo.delete!(repo)
                end) do
              {:ok, %{} = _} -> {:ok, :deleted}
              {:error, reason} ->
                # DB delete failed even though FS was removed — log and return error
                Logger.error("DB delete failed when hard-deleting repo #{repo.id}: #{inspect(reason)}")
                {:error, {:db_delete_failed, reason}}
              other ->
                # Unexpected return shape
                Logger.error("Unexpected Repo.transaction result when hard-deleting repo #{repo.id}: #{inspect(other)}")
                {:error, {:unexpected, other}}
            end

          {:error, reason} ->
            Logger.error("Failed to remove repo dir for hard-delete #{repo.id}: #{inspect(reason)}")
            {:error, {:rm_failed, reason}}

          # Some store implementations may return other truthy values; treat them as success
          other ->
            Logger.debug("store().delete_repo_dir returned: #{inspect(other)}; proceeding to DB delete")
            case Repo.transaction(fn -> Repo.delete!(repo) end) do
              {:ok, %{} = _} -> {:ok, :deleted}
              {:error, reason} ->
                Logger.error("DB delete failed when hard-deleting repo #{repo.id}: #{inspect(reason)}")
                {:error, {:db_delete_failed, reason}}
              other2 ->
                Logger.error("Unexpected Repo.transaction result when hard-deleting repo #{repo.id}: #{inspect(other2)}")
                {:error, {:unexpected, other2}}
            end
        end
      end
    else
      {:error, :not_found} -> {:error, :not_found}
    end
  end

  @doc """
  Get repository by id or name. Does NOT return soft-deleted by default: if repository has deleted_at set,
  it is considered deleted and will not be returned unless explicit opts allow it.
  """
  def get_repository(id_or_name, opts \\ []) when is_binary(id_or_name) do
    allow_deleted = Keyword.get(opts, :allow_deleted, false)

    case fetch_by_id_or_name(id_or_name) do
      {:ok, repo} ->
        if repo.deleted_at && not allow_deleted do
          {:error, :not_found}
        else
          {:ok, repo}
        end

      {:error, :not_found} -> {:error, :not_found}
    end
  end

  @doc """
  List repositories. By default hides soft-deleted. Pass `include_deleted: true` in opts to show all.
  """
  def list_repositories(opts \\ []) do
    include_deleted = Keyword.get(opts, :include_deleted, false)

    base =
      from r in Repository,
        order_by: [asc: r.name]

    query =
      if include_deleted do
        base
      else
        from r in base, where: is_nil(r.deleted_at)
      end

    Repo.all(query)
  end

  # Helper: look up by id (UUID) first, otherwise by name
  defp fetch_by_id_or_name(id_or_name) do
    cond do
      looks_like_uuid?(id_or_name) ->
        case Repo.get(Repository, id_or_name) do
          nil -> fetch_by_name(id_or_name)
          repo -> {:ok, repo}
        end

      true ->
        fetch_by_name(id_or_name)
    end
  end

  defp fetch_by_name(name) do
    case Repo.get_by(Repository, name: name) do
      nil -> {:error, :not_found}
      repo -> {:ok, repo}
    end
  end

  defp looks_like_uuid?(value) when is_binary(value) do
    case Ecto.UUID.cast(value) do
      {:ok, _} -> true
      _ -> false
    end
  end
end

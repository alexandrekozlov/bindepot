Generate context implementation that uses new storage API and adapter registry.

=================

### Lib/bindepot/core/repositories

```

defmodule Bindepot.Core.Repositories do
  @moduledoc """
  Top-level repository context (package-agnostic).

  Responsibilities:
  - manage repository lifecycle (create, soft-delete, hard-delete, get, list)
  - use configured storage backend (Bindepot.Storage.Store) for filesystem operations
  - delegate package-type-specific operations to adapters via Bindepot.PackageAdapters

  Note: package-specific state and validation lives in adapter modules. The core context
  only passes through `package_attrs` to adapter when adapter implements `create_repo/2`.
  """

  import Ecto.Query, warn: false
  alias Bindepot.Repo
  alias Bindepot.Core.Repository
  alias Bindepot.PackageAdapters

  require Logger

  # storage backend module (defaults to LocalStore)
  defp store, do: Application.get_env(:bindepot, :store, Bindepot.Storage.LocalStore)

  @doc "Get data_dir from store"
  def data_dir, do: store().data_dir()

  @doc "Get repo_path for a repository id"
  def repo_path(id), do: store().repo_path(id)

  @doc "Create repository and (optionally) delegate package-specific initialisation to adapter.
  attrs may include :package_attrs (map) which will be forwarded to adapter.create_repo/2 if available.

  Returns `{:ok, repo}` or `{:error, changeset | reason}`.
  """
  def create_repository(attrs) when is_map(attrs) do
    package_attrs = Map.get(attrs, "package_attrs", Map.get(attrs, :package_attrs, %{}))
    desired_id = Map.get(attrs, "id") || Map.get(attrs, :id)

    id_for_path = if is_binary(desired_id), do: desired_id, else: Ecto.UUID.generate()

    case store().create_repo_dir(id_for_path) do
      :ok ->
        attrs_with_id = Map.put(attrs, :id, id_for_path)

        Repo.transaction(fn ->
          changeset = Repository.changeset(%Repository{}, attrs_with_id)
          repo = Repo.insert!(changeset)

          # Delegate package-specific repo creation to adapter if adapter implements it.
          maybe_call_adapter_create(repo, package_attrs)

          repo
        end)
        |> case do
          {:ok, repo} -> {:ok, repo}
          {:error, reason} ->
            # compensating cleanup: remove dir
            _ = store().delete_repo_dir(id_for_path)
            {:error, reason}
        end

      {:error, reason} -> {:error, {:mkdir_failed, reason}}
    end
  rescue
    e ->
      # make best-effort cleanup on unexpected crash
      _ = store().delete_repo_dir(id_for_path)
      reraise e, __STACKTRACE__
  end

  defp maybe_call_adapter_create(%Repository{package_type: pkg, id: id} = repo, package_attrs) do
    case PackageAdapters.for_type(pkg) do
      nil ->
        # no adapter registered; nothing to do
        :ok

      adapter when is_atom(adapter) ->
        # if adapter exports create_repo/2 then call it. It should return {:ok, any} or {:error, reason}
        if function_exported?(adapter, :create_repo, 2) do
          case adapter.create_repo(repo, package_attrs) do
            {:ok, _} -> :ok
            {:error, reason} ->
              # if adapter creation fails, raise to abort DB transaction so we can cleanup FS
              raise "adapter.create_repo failed: #{inspect(reason)}"
          end
        else
          :ok
        end
    end
  end

  @doc "Soft-delete repository by id or name. Sets deleted_at and attempts to delete filesystem."
  def delete_repository(id_or_name) when is_binary(id_or_name) do
    with {:ok, repo} <- fetch_by_id_or_name(id_or_name) do
      now = NaiveDateTime.utc_now() |> NaiveDateTime.truncate(:second)
      changeset = Ecto.Changeset.change(repo, deleted_at: now)

      case Repo.update(changeset) do
        {:ok, updated} ->
          case store().delete_repo_dir(updated.id) do
            :ok -> {:ok, updated}
            {:error, reason} ->
              Logger.error("Failed to remove repository dir for #{updated.id}: #{inspect(reason)}")
              {:ok, updated}
          end

        {:error, reason} -> {:error, reason}
      end
    else
      {:error, :not_found} -> {:error, :not_found}
    end
  end

  @doc "Hard-delete (purge) repository: optionally require soft-delete first."
  def hard_delete_repository(id_or_name, opts \\ []) when is_binary(id_or_name) do
    require_soft_deleted = Keyword.get(opts, :require_soft_deleted, true)

    with {:ok, repo} <- fetch_by_id_or_name(id_or_name) do
      if require_soft_deleted and is_nil(repo.deleted_at) do
        {:error, :not_soft_deleted}
      else
        # Attempt remove files first to avoid orphaned files
        case store().delete_repo_dir(repo.id) do
          :ok ->
            case Repo.transaction(fn -> Repo.delete!(repo) end) do
              {:ok, _} -> {:ok, :deleted}
              {:error, reason} ->
                Logger.error("DB delete failed when hard-deleting repo #{repo.id}: #{inspect(reason)}")
                {:error, {:db_delete_failed, reason}}
            end

          {:error, reason} ->
            Logger.error("Failed to remove repo dir for hard-delete #{repo.id}: #{inspect(reason)}")
            {:error, {:rm_failed, reason}}

          other ->
            Logger.debug("store().delete_repo_dir returned: #{inspect(other)}; proceeding to DB delete")
            case Repo.transaction(fn -> Repo.delete!(repo) end) do
              {:ok, _} -> {:ok, :deleted}
              {:error, reason} -> {:error, {:db_delete_failed, reason}}
            end
        end
      end
    else
      {:error, :not_found} -> {:error, :not_found}
    end
  end

  @doc "Get repository by id or name. Does not return soft-deleted unless allow_deleted: true."
  def get_repository(id_or_name, opts \\ []) when is_binary(id_or_name) do
    allow_deleted = Keyword.get(opts, :allow_deleted, false)

    case fetch_by_id_or_name(id_or_name) do
      {:ok, repo} ->
        if repo.deleted_at && not allow_deleted, do: {:error, :not_found}, else: {:ok, repo}

      {:error, :not_found} -> {:error, :not_found}
    end
  end

  @doc "List repositories. Pass include_deleted: true to include soft-deleted rows."
  def list_repositories(opts \\ []) do
    include_deleted = Keyword.get(opts, :include_deleted, false)

    base = from r in Repository, order_by: [asc: r.name]

    query = if include_deleted, do: base, else: from r in base, where: is_nil(r.deleted_at)

    Repo.all(query)
  end

  # helpers
  defp fetch_by_id_or_name(id_or_name) do
    cond do
      looks_like_uuid?(id_or_name) ->
        case Repo.get(Repository, id_or_name) do
          nil -> fetch_by_name(id_or_name)
          repo -> {:ok, repo}
        end

      true -> fetch_by_name(id_or_name)
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
```

Done — I added the core context implementation as a separate file on the canvas:

* `lib/bindepot/core/repositories.ex`

What's included:

* `create_repository/1` (uses the `store` API to create repo dir, inserts `repositories` row, and delegates package-specific repo initialization to the adapter if it exports `create_repo/2`).
* `delete_repository/1` (soft-delete + tries to remove storage dir).
* `hard_delete_repository/2` (purge: deletes storage dir then hard-deletes DB rows; optional `require_soft_deleted`).
* `get_repository/2` and `list_repositories/1`.
* Helper functions for fetching by id/name and UUID checking.

If you want, I can now:

* Wire this context into an `BindepotWeb` controller for HTTP endpoints.
* Implement the adapter-side `create_repo/2` stubs for package modules (PyPI, NPM, etc.) so `create_repository/1` can fully delegate initialization.
* Add tests for core operations with a mocked `:store` and in-memory sandboxed `Repo`.

Which should I do next?

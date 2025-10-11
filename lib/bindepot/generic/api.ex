defmodule Bindepot.Generic.API do
  alias Bindepot.Core.Repositories

  def upload(repo_id, _metadata, _stream) do
    with {:ok, repo} <- Repositories.get(repo_id),
         :ok <- ensure_not_deleted(repo),
         :ok <- validate_repo_config(repo),
         :ok <- store().create_repo_dir(repo.id) do
      # layout: Path.join(Store.repo_path(repo.id), repo.configuration["simple_index_path"], metadata["name"])
      # write file, insert metadata row, return result
    end
  end

  defp validate_repo_config(%{configuration: cfg}) do
    if Map.has_key?(cfg, "simple_index_path"), do: :ok, else: {:error, :missing_config}
  end

  defp ensure_not_deleted(%{deleted_at: nil}), do: :ok
  defp ensure_not_deleted(_), do: {:error, :deleted}

  defp store, do: Application.get_env(:bindepot, :store, LocalStore)
end

defmodule Bindepot.PyPI.API do
  @moduledoc "PyPI-specific API: upload, list_packages, get_package, delete_package."

  import Ecto.Query

  require Logger
  alias Bindepot.Repo
  alias Bindepot.Core.Repositories, as: CoreRepos
  alias Bindepot.PyPI.{Package, Release, DistFile}
  alias Bindepot.Storage.LocalStore

  @doc """
  Upload a distribution file for a package. Supports:
    - source path (string)
    - %Plug.Upload{}
    - Enumerable/Stream (chunks of binaries)
  """
  def upload(repo_id, metadata, source) when is_binary(repo_id) and is_map(metadata) do
    with {:ok, repo} <- CoreRepos.get_repository(repo_id),
         :ok <- ensure_not_deleted(repo),
         :ok <- validate_repo_config(repo) do

      simple_path = repo.configuration["simple_index_path"] || "simple"
      package_name = metadata["name"] || metadata[:name]
      version = metadata["version"] || metadata[:version]
      filename = metadata["filename"] || metadata[:filename]

      if is_nil(package_name) or is_nil(version) or is_nil(filename) do
        {:error, :invalid_metadata}
      else
        tmp_dir = Path.join([store().cache_dir(), "uploads", repo.id])
        :ok = File.mkdir_p(tmp_dir)
        tmp_file = Path.join(tmp_dir, "#{Ecto.UUID.generate()}-#{filename}")

        case write_source_to_tmp_streaming(source, tmp_file) do
          {:ok, %{size: size, sha256: sha256}} ->
            final_dir = Path.join([store().repo_path(repo.id), simple_path, package_name])
            :ok = File.mkdir_p(final_dir)
            final_path = Path.join(final_dir, filename)

            case store().upload_temp_to_final(tmp_file, final_path) do
              :ok ->
                # store relative path
                rel_path = Path.relative_to(final_path, store().data_dir())

                res = Repo.transaction(fn ->
                  pkg = get_or_create_package!(repo.id, package_name, metadata)
                  rel = get_or_create_release!(pkg, version, metadata)
                  df_attrs = %{
                    release_id: rel.id,
                    filename: filename,
                    file_path: rel_path,
                    size: size,
                    sha256: sha256,
                    content_type: metadata["content_type"] || metadata[:content_type]
                  }

                  %DistFile{} |> DistFile.changeset(df_attrs) |> Repo.insert!()
                end)

                case res do
                  {:ok, dist_file} -> {:ok, dist_file}
                  {:error, reason} ->
                    _ = safe_rm(final_path)
                    {:error, reason}
                end

              {:error, reason} ->
                _ = safe_rm(tmp_file)
                {:error, {:move_failed, reason}}
            end

          {:error, reason} ->
            _ = safe_rm(tmp_file)
            {:error, reason}
        end
      end
    end
  end

  # streaming write + sha256 calculation
  defp write_source_to_tmp_streaming(%Plug.Upload{path: path}, tmp_file), do: write_source_to_tmp_streaming(path, tmp_file)

  defp write_source_to_tmp_streaming(path, tmp_file) when is_binary(path) do
    # copy by streaming to avoid reading whole file into memory
    case File.open(path, [:read, :binary]) do
      {:ok, rfd} ->
        case File.open(tmp_file, [:write, :binary]) do
          {:ok, wfd} ->
            try do
              ctx = :crypto.hash_init(:sha256)
              {ctx2, bytes} = stream_copy_and_hash(rfd, wfd, ctx, 0)
              :ok = File.close(rfd)
              :ok = File.close(wfd)
              sha256 = :crypto.hash_final(ctx2) |> Base.encode16(case: :lower)
              {:ok, %{size: bytes, sha256: sha256}}
            rescue e ->
              _ = File.close(rfd)
              _ = File.close(wfd)
              _ = safe_rm(tmp_file)
              {:error, {:write_failed, e}}
            end
          {:error, reason} -> File.close(rfd); {:error, {:open_tmp_failed, reason}}
        end
      {:error, reason} -> {:error, {:open_src_failed, reason}}
    end
  end

  defp write_source_to_tmp_streaming(enum, tmp_file) do
    case File.open(tmp_file, [:write, :binary]) do
      {:ok, wfd} ->
        try do
          ctx = :crypto.hash_init(:sha256)
          {ctx2, bytes} = enum_stream_write_and_hash(enum, wfd, ctx, 0)
          :ok = File.close(wfd)
          sha256 = :crypto.hash_final(ctx2) |> Base.encode16(case: :lower)
          {:ok, %{size: bytes, sha256: sha256}}
        rescue e ->
          _ = File.close(wfd)
          _ = safe_rm(tmp_file)
          {:error, {:write_failed, e}}
        end
      {:error, reason} -> {:error, {:open_tmp_failed, reason}}
    end
  end

  defp stream_copy_and_hash(rfd, wfd, ctx, acc_bytes) do
    case :file.read(rfd, 65536) do
      {:ok, data} ->
        :ok = IO.binwrite(wfd, data)
        ctx2 = :crypto.hash_update(ctx, data)
        stream_copy_and_hash(rfd, wfd, ctx2, acc_bytes + byte_size(data))
      :eof -> {ctx, acc_bytes}
      {:error, reason} -> raise {:read_failed, reason}
    end
  end

  defp enum_stream_write_and_hash(enum, wfd, ctx, acc_bytes) do
    stream = if is_function(enum, 0), do: enum.(), else: enum
    Enum.reduce(stream, {ctx, acc_bytes}, fn chunk, {c, b} ->
      :ok = IO.binwrite(wfd, chunk)
      { :crypto.hash_update(c, chunk), b + byte_size(chunk) }
    end)
    |> then(fn {c2, bytes} -> {c2, bytes} end)
  end

  defp safe_rm(path) do
    case File.rm(path) do
      :ok -> :ok
      {:error, _} -> :ok
    end
  end

  defp store, do: Application.get_env(:bindepot, :store, LocalStore)

  defp ensure_not_deleted(%{deleted_at: nil}), do: :ok
  defp ensure_not_deleted(_), do: {:error, :repo_deleted}

  defp validate_repo_config(%{configuration: cfg}) when is_map(cfg), do: :ok
  defp validate_repo_config(_), do: {:error, :invalid_configuration}

  # DB helpers
  defp get_or_create_package!(repo_id, name, metadata) do
    normalized = normalize_name(name)
    case Repo.get_by(Package, repo_id: repo_id, normalized_name: normalized) do
      nil ->
        attrs = %{name: name, normalized_name: normalized, repo_id: repo_id, metadata: metadata}
        %Package{} |> Package.changeset(attrs) |> Repo.insert!()
      pkg -> pkg
    end
  end

  defp get_or_create_release!(%Package{id: pkg_id}, version, metadata) do
    case Repo.get_by(Release, pkg_id: pkg_id, version: version) do
      nil ->
        attrs = %{pkg_id: pkg_id, version: version, released_at: NaiveDateTime.utc_now() |> NaiveDateTime.truncate(:second), metadata: metadata}
        %Release{} |> Release.changeset(attrs) |> Repo.insert!()
      rel -> rel
    end
  end

  defp normalize_name(name) when is_binary(name), do: String.downcase(name)

  # List packages for a repo
  def list_packages(repo_id, opts \\ %{}) do
    limit = Map.get(opts, :limit, 100)
    Repo.all(from p in Package, where: p.repo_id == ^repo_id, limit: ^limit, order_by: [asc: p.normalized_name])
  end

  def get_package(repo_id, name) do
    normalized = normalize_name(name)
    case Repo.get_by(Package, repo_id: repo_id, normalized_name: normalized) do
      nil -> {:error, :not_found}
      pkg -> {:ok, pkg}
    end
  end

  def delete_package(repo_id, name, version \\ nil) do
    normalized = normalize_name(name)
    case Repo.get_by(Package, repo_id: repo_id, normalized_name: normalized) do
      nil -> {:error, :not_found}
      pkg ->
        if version do
          case Repo.get_by(Release, pkg_id: pkg.id, version: version) do
            nil -> {:error, :not_found}
            rel ->
              # delete dist files and releases and possibly package if no more releases
              Repo.transaction(fn ->
                Repo.delete_all(from df in DistFile, where: df.release_id == ^rel.id)
                Repo.delete!(rel)
              end)
          end
        else
          # delete whole package (cascades releases/files)
          Repo.transaction(fn ->
            Repo.delete!(pkg)
          end)
        end
    end
  end
end

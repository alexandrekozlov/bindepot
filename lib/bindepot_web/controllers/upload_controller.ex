defmodule BindepotWeb.UploadController do
  use BindepotWeb, :controller

  alias BindepotWeb.Api.AssetController
  alias Bindepot.Core.Repositories
  alias Bindepot.Core.Assets

  def upload(conn, %{"repo" => repo_key, "path" => asset_path} = params) do
    IO.inspect(params)

    repo = Repositories.get_by_name(repo_key)

    case repo.package_type do
      "generic" ->
        AssetController.upload(conn, params)

      "pypi" ->
        # TODO: Factor out into a separate core module (except for HTTP response lines)
        # TODO: Create package/version record
        case asset_path do
          ["simple"] ->
            %{
              "name" => package_name,
              "version" => package_version,
              "md5_digest" => _md5_digest,
              "content" => %{path: temp_file, filename: asset_filename}
            } = params

            store_path =
              "/"
              |> Path.join(package_name)
              |> Path.join(package_version)

            # TODO: Problem here that we put the asset in, but only then can verify
            # hash. Yes, we can delete the invalid asset, but that is a problem that
            # invalid package already replaced the good one, if one was already
            # there. Solution is more fine grained control over the storage process.
            #   1. Either split into multiple stages (calc hash, verify, record)
            #   2. Provide validation info (expected hashes) as an extra parameter
            #   3. (preferred) Provide a function parameter that is called after hash is
            #      computed, but before file is stored and recorded in DB.
            {:ok, asset_info} = Assets.put(repo.id, asset_filename, store_path, temp_file)
            resp = BindepotWeb.Api.Utils.sanitize_schema(asset_info)
            IO.inspect(resp)

            conn
            |> put_resp_content_type("application/json")
            |> send_resp(200, Jason.encode!(resp, pretty: true))

          _ ->
            conn
            |> put_resp_content_type("text/plain")
            |> send_resp(501, "'#{asset_path}' not supported")
        end

      _ ->
        conn
        |> put_resp_content_type("text/plain")
        |> send_resp(501, "package type '#{repo.package_type}' not implemented")
    end
  end

  def legacy_upload(conn, params) do
    # enforce auth
    # use Repository.create_upload/2 to save uploaded file and metadata
    case handle_legacy_upload(params) do
      {:ok, record} ->
        conn
        |> put_resp_content_type("application/json")
        |> send_resp(200, Jason.encode!(%{ok: true, id: record.id}))

      {:error, reason} ->
        conn
        |> put_resp_content_type("application/json")
        |> send_resp(400, Jason.encode!(%{error: inspect(reason)}))
    end
  end

  defp handle_legacy_upload(params) do
    # repository key
    repo_key = Map.get(params, "repo")
    # package name
    name = Map.get(params, "name")
    # package version
    version = Map.get(params, "version")
    # upload content
    upload = Map.get(params, "content")

    repo = Repositories.get_by_name(repo_key)

    with :local = repo.type,
         :pypi = repo.package_type do
      case upload do
        %Plug.Upload{filename: fname, path: path} ->
          Assets.put(repo, fname, Path.join([name, version, fname]), path)
          {:ok, "good"}

        _ ->
          {:error, "upload problem"}
      end
    end
  end
end

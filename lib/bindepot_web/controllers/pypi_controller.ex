defmodule BindepotWeb.PypiController do
  use BindepotWeb, :controller

  alias Bindepot.Core.Repositories
  alias Bindepot.Core.Assets

  def simple_upload(conn, params) do
    IO.inspect(params)

    conn
    |> put_resp_content_type("application/json")
    |> send_resp(200, Jason.encode!(%{ok: true}))
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

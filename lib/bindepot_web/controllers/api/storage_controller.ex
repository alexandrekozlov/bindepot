defmodule BindepotWeb.Api.StorageController do
  use BindepotWeb, :controller

  alias Bindepot.Repo
  alias Bindepot.Core.Nodes
  alias BindepotWeb.Api.Utils

  def get(conn, %{"path" => path, "list" => _}) do
    repo = conn.assigns.repository

    resp =
      Nodes.all(repo.id, Enum.join(path, "/"))
      |> Repo.preload([:blob])
      |> Enum.map(fn asset ->
        %{
          type: asset.type,
          path: asset.path,
          name: asset.name,
          size: if(is_nil(asset.blob), do: -1, else: asset.blob.size)
        }
      end)
      |> IO.inspect()

    conn
    |> put_resp_content_type("application/json")
    |> send_resp(200, Jason.encode!(resp, pretty: true))
  end

  def get(conn, %{"path" => path}) do
    repo = conn.assigns.repository

    resp =
      case Nodes.get(repo.id, "/" <> Enum.join(path, "/")) do
        :root ->
          %{
            name: repo.name,
            type: repo.type,
            package_type: repo.package_type,
            url: repo.url,
            repositories: repo.repositories,
            created:
              repo.inserted_at &&
                DateTime.from_naive!(repo.inserted_at, "Etc/UTC") |> DateTime.to_iso8601(),
            updated:
              repo.updated_at &&
                DateTime.from_naive!(repo.updated_at, "Etc/UTC") |> DateTime.to_iso8601()
          }

        nil ->
          nil

        node ->
          node
          |> Utils.sanitize_schema()
      end

    case resp do
      nil ->
        conn
        |> put_resp_content_type("application/json")
        |> send_resp(404, "path do not refer to an entry")

      _ ->
        conn
        |> put_resp_content_type("application/json")
        |> send_resp(200, Jason.encode!(resp, pretty: true))
    end
  end
end

defmodule BindepotWeb.Api.StorageController do
  use BindepotWeb, :controller

  alias Bindepot.Repo
  alias Bindepot.Core.Nodes
  alias BindepotWeb.Api.Utils

  def handle_get(conn, %{"path" => path} = params) do
    get_info(conn, params)
  end

  def get_info(conn, %{"path" => path}) do
    repo = conn.assigns.repository

    resp =
      Nodes.all(repo.id, "/" <> Enum.join(path, "/"))
      |> Repo.preload([:blob])
      |> Utils.sanitize_schema()
      # |> Enum.map(fn asset ->
      #   %{
      #     type: asset.type,
      #     path: asset.path,
      #     name: asset.name,
      #     size: if(is_nil(asset.blob), do: -1, else: asset.blob.size)
      #   }
      # end)
      |> IO.inspect()

    conn
    |> put_resp_content_type("application/json")
    |> send_resp(200, Jason.encode!(resp, pretty: true))
  end

  def list(conn, %{"path" => path}) do
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
end

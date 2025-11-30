defmodule BindepotWeb.Api.AssetController do
  use BindepotWeb, :controller

  alias Bindepot.Repo
  alias Bindepot.Core.Assets
  alias Bindepot.Core.Nodes
  alias Bindepot.Core.Repositories
  alias BindepotWeb.Api.Utils

  def handle_get(conn, %{"path" => path} = params) do
    case Map.has_key?(params, "list") do
      true -> list(conn, path)
      false -> download(conn, path)
    end
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

  def download(conn, %{"path" => path}) do
    repo = conn.assigns.repository

    rel_path = Enum.join(path, "/")
    # TODO: Error out if rel_path is a directory
    stream = Assets.get_stream(repo.id, rel_path)

    conn
    |> put_resp_content_type("application/octet-stream")
    |> put_resp_header(
      "content-disposition",
      "attachment; filename=\"#{Path.basename(rel_path)}\""
    )
    |> send_chunked(200)
    |> then(fn c ->
      Enum.reduce(stream, c, fn chunk, acc_conn ->
        case Plug.Conn.chunk(acc_conn, chunk) do
          {:ok, new_conn} -> new_conn
          {:error, :closed} -> acc_conn
        end
      end)
    end)
  end

  def upload(conn, %{"repo" => repo_name, "path" => path}) do
    repo = Repositories.get_by_name(repo_name)

    rel_artifact_path =
      path
      |> Path.join()
      |> Path.expand("/")

    stream = Utils.request_body_as_stream(conn)
    {:ok, node} = Assets.put_stream(repo.id, rel_artifact_path, stream, replace: true)
    IO.inspect(node)

    resp = Utils.sanitize_schema(node)

    conn
    |> put_resp_content_type("application/json")
    |> send_resp(200, Jason.encode!(resp, pretty: true))
  end
end

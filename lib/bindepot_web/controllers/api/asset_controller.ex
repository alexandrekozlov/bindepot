defmodule BindepotWeb.Api.AssetController do
  use BindepotWeb, :controller

  alias Bindepot.Core.Assets
  alias BindepotWeb.Api.Utils

  def download(conn, %{"path" => path}) do
    repo = conn.assigns.repository

    rel_path = Enum.join(path, "/")
    stream = Assets.get_stream(repo.id, rel_path)

    if is_nil(stream) do
      conn
      |> put_resp_content_type("application/json")
      |> send_resp(404, ~S({ "error": "path does not point to a file" }))
    else
      conn
      |> put_resp_content_type("application/octet-stream")
      |> Utils.send_chunked_stream(Path.basename(rel_path), stream)
    end
  end

  def upload(conn, %{"path" => path}) do
    repo = conn.assigns.repository

    rel_path = Enum.join(path, "/")

    stream = Utils.request_body_as_stream(conn)
    {:ok, node} = Assets.put_stream(repo.id, rel_path, stream, replace: true)

    resp = Utils.sanitize_schema(node)

    conn
    |> put_resp_content_type("application/json")
    |> send_resp(200, Jason.encode!(resp, pretty: true))
  end
end

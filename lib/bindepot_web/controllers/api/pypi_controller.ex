defmodule BindepotWeb.Api.PypiController do
  use BindepotWeb, :controller

  alias Bindepot.Pypi.HtmlIndex
  alias Bindepot.Core.Repository
  alias Bindepot.Core.Assets
  alias Bindepot.Core.DistFiles
  alias Bindepot.Pypi.RepoIndex

  alias BindepotWeb.Api.Utils

  # https://peps.python.org/pep-0425/
  # https://peps.python.org/pep-0503/
  # https://peps.python.org/pep-0691/
  # https://peps.python.org/pep-0700/
  # https://peps.python.org/pep-0721/
  # https://packaging.python.org/en/latest/specifications/source-distribution-format/#sdist-archive-features
  # https://packaging.python.org/en/latest/specifications/
  # https://packaging.python.org/en/latest/specifications/section-package-indices/
  # https://docs.pypi.org/api/index-api/
  #

  @use_proxy false

  # Hop-by-hop headers that should NOT be forwarded
  @excluded_headers ~w(
      connection
      keep-alive
      proxy-authenticate
      proxy-authorization
      te
      trailers
      transfer-encoding
      upgrade
      host
    )

  def local_repo_index(conn, _params) do
    body =
      RepoIndex.get_local_repo_index(conn.assigns.repository.id)
      |> HtmlIndex.to_html_repo_simple_index()

    conn
    |> put_resp_content_type("text/html")
    |> send_resp(200, body)
  end

  def fetch_remote_repo_index(%Repository{id: id, url: url} = _repo) do
    repo_index_url = "#{String.trim_trailing(url, "/")}/simple/"
    file = Utils.download(repo_index_url)
    Assets.put_file(id, "/.pypi/index.html", file, replace: true)
  end

  def upload(conn, %{"path" => ["legacy"]} = params) do
    repo = conn.assigns.repository

    %{
      "name" => package_name,
      "version" => package_version,
      "content" => %{path: temp_file, filename: asset_filename}
    } = params

    store_path =
      "/"
      |> Path.join(package_name)
      |> Path.join(package_version)
      |> Path.join(asset_filename)

    {:ok, node} = Assets.put_file(repo.id, store_path, temp_file, replace: true)

    pkg =
      DistFiles.create(
        asset_filename,
        "application/octet-stream",
        package_version,
        package_name,
        "pypi",
        node
      )

    resp = BindepotWeb.Api.Utils.sanitize_schema(pkg)

    conn
    |> put_resp_content_type("application/json")
    |> send_resp(200, Jason.encode!(resp, pretty: true))
  end

  def upload(conn, %{"path" => uri}) do
    conn
    |> put_resp_content_type("text/plain")
    |> send_resp(400, "'#{uri}' cannot be used for upload. Use '/legacy'.")
  end

  def download(%{request_path: request_path} = conn, %{"path" => path} = params) do
    cond do
      conn.assigns.repository.type == "remote" ->
        if @use_proxy do
          IO.inspect(path)
          proxy(conn, path)
        else
          case path do
            ["simple"] ->
              handle_remote_repo_index(conn, params)

            ["simple", package] ->
              handle_remote_package_index(conn, package, params)
          end
        end

      String.last(request_path) != "/" ->
        redirect(conn, to: "#{request_path}/")

      path == ["simple"] ->
        list_packages(conn, params)

      true ->
        conn
        |> put_resp_content_type("text/plain")
        |> send_resp(400, "'#{request_path}' cannot be used for upload. Use '/simple/'.")
    end
  end

  defp handle_remote_repo_index(conn, _params) do
    {:ok, index} = RepoIndex.get_remote_repo_index(conn.assigns.repository.id)
    body = index |> HtmlIndex.to_html_repo_simple_index()

    conn
    |> put_resp_content_type("text/html")
    |> send_resp(200, body)
  end

  defp handle_remote_package_index(conn, package, _params) do
    IO.inspect(package)
    {:ok, index} = RepoIndex.get_remote_repo_index(conn.assigns.repository.id)

    case Map.get(index, package, nil) |> IO.inspect() do
      nil ->
        conn
        |> put_resp_content_type("text/plain")
        |> send_resp(404, "not found")

      %{"uri" => url} ->
        {:ok, index} = RepoIndex.get_remote_package_index(conn.assigns.repository.id, url)

        body = index |> IO.inspect() |> HtmlIndex.to_html_repo_simple_index()

        conn
        |> put_resp_content_type("text/html")
        |> send_resp(200, body)
    end
  end

  defp list_packages(conn, _params) do
    repo = conn.assigns.repository

    assets = Assets.all(repo)

    body =
      "<!DOCTYPE html>\n<html>\n<body>" <>
        (assets
         |> Enum.reduce([], fn asset, b ->
           a =
             "<a href=\"#{asset.path}/#{asset.name}#sha256=#{asset.sha256}\">#{asset.name}</a><br/>"

           [a | b]
         end)
         |> Enum.reverse()
         |> Enum.join("\n")) <> "</body></html>\n"

    conn
    |> put_resp_content_type("text/html")
    |> send_resp(200, body)
  end

  def proxy(conn, path_segments) do
    repo = conn.assigns.repository

    upstream_url = build_upstream_url(repo.url, path_segments, conn.query_string)

    # method = conn.method |> String.to_atom()

    # Extract body (works for POST/PUT multipart too)
    {:ok, body, _conn} = read_body(conn)

    # Forward headers, removing hop-by-hop headers
    headers =
      conn.req_headers
      |> Enum.reject(fn {k, _} -> k in @excluded_headers end)

    request = Finch.build(:get, upstream_url, headers, body)
    IO.inspect(request)

    case Finch.request(request, Bindepot.Finch) do
      {:ok, %Finch.Response{} = resp} ->
        resp |>IO.inspect()
        conn
        |> put_resp_headers(resp.headers)
        |> send_resp(resp.status, resp.body)

      {:error, err} ->
        send_resp(conn, 502, "Proxy Error: #{inspect(err)}")
    end
  end

  defp build_upstream_url(url, path_segments, query_string) do
    path = Enum.join(path_segments, "/")
    base = "#{String.trim_trailing(url, "/")}/#{path}/"

    if query_string == "" do
      base
    else
      base <> "?" <> query_string
    end
  end

  defp put_resp_headers(conn, headers) do
    headers
    |> Enum.reject(fn {k, _} -> k in @excluded_headers end)
    |> Enum.reduce(conn, fn {k, v}, c -> put_resp_header(c, k, v) end)
  end
end

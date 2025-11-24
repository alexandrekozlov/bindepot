defmodule BindepotWeb.Api.PypiController do
  use BindepotWeb, :controller

  alias Bindepot.Core.Assets

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

  def upload(conn, %{"path" => ["legacy"]} = params) do
    repo = conn.assigns.repository

    # TODO: Create package/version record
    %{
      "name" => package_name,
      "version" => package_version,
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
  end

  def upload(conn, %{"path" => uri}) do
    conn
    |> put_resp_content_type("text/plain")
    |> send_resp(400, "'#{uri}' cannot be used for upload. Use '/legacy'.")
  end

  def download(%{request_path: request_path} = conn, %{"path" => path} = params) do
    cond do
      conn.assigns.repository.type == "remote" ->
        proxy(conn, path)

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

    case Finch.request(request, MyApp.Finch) do
      {:ok, %Finch.Response{} = resp} ->
        conn
        |> put_resp_headers(resp.headers)
        |> send_resp(resp.status, resp.body)

      {:error, err} ->
        send_resp(conn, 502, "Proxy Error: #{inspect(err)}")
    end
  end

  defp build_upstream_url(url, path_segments, query_string) do
    path = Enum.join(path_segments, "/")
    base = "#{String.trim_trailing(url, "/")}/#{path}"

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

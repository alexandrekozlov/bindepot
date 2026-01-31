defmodule BindepotWeb.Api.RepositoryIoController do
  @moduledoc """
    This module requires `assigns.repository` value, which is a repository object.
    One can use Bindepot.Plugs.GetRepository router plug to retrieve repository
    instance based on `repo` request parameter.
  """
  use BindepotWeb, :controller

  alias BindepotWeb.Api.AssetController
  alias BindepotWeb.Api.PypiController

  def handle_request(%{method: method} = conn, params) do
    repo = conn.assigns.repository

    case repo.package_type do
      "generic" ->
        case method do
          "POST" ->
            AssetController.upload(conn, params)

          "GET" ->
            AssetController.download(conn, params)

          _ ->
            conn
            |> put_resp_content_type("text/plain")
            |> send_resp(405, "Method Not Allowed")
        end

      "pypi" ->
        case method do
          "POST" ->
            PypiController.upload(conn, params)

          "GET" ->
            PypiController.download(conn, params)

          _ ->
            conn
            |> put_resp_content_type("text/plain")
            |> send_resp(405, "Method Not Allowed")
        end

      _ ->
        conn
        |> put_resp_content_type("text/plain")
        |> send_resp(501, "package type '#{repo.package_type}' not implemented")
    end
  end
end

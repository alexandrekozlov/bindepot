defmodule BindepotWeb.Api.RepositoryIoController do
  @moduledoc """
    This module requires `assigns.repository` value, which is a repository object.
    One can use Bindepot.Plugs.GetRepository router plug to retrieve repository
    instance based on `repo` request parameter.
  """
  use BindepotWeb, :controller

  alias BindepotWeb.Api.AssetController
  alias BindepotWeb.Api.PypiController

  # TODO: May be move all logic into a plug and have custom router macros?

  def upload(conn, params) do
    IO.inspect(params)

    repo = conn.assigns.repository

    case repo.package_type do
      "generic" ->
        AssetController.upload(conn, params)

      "pypi" ->
        PypiController.upload(conn, params)

      _ ->
        conn
        |> put_resp_content_type("text/plain")
        |> send_resp(501, "package type '#{repo.package_type}' not implemented")
    end
  end

  def download(conn, params) do
    IO.inspect(conn)
    IO.inspect(params)

    repo = conn.assigns.repository

    case repo.package_type do
      "generic" ->
        AssetController.download(conn, params)

      "pypi" ->
        PypiController.download(conn, params)

      _ ->
        conn
        |> put_resp_content_type("text/plain")
        |> send_resp(501, "package type '#{repo.package_type}' not implemented")
    end
  end
end

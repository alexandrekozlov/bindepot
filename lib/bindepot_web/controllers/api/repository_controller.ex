defmodule BindepotWeb.Api.RepositoryController do
  use BindepotWeb, :controller

  alias Bindepot.Core.Repositories

  def create_repository(conn, %{"repository" => repository_name} = params) do
    repository_type = Map.get(params, "repository_type", :local)
    package_type = Map.get(params, "package_type", "generic")

    {:ok, id} =
      Repositories.create(%{
        name: repository_name,
        repository_type: repository_type,
        package_type: package_type,
        configuration: params,
        properties: %{}
      })

    conn
    |> put_resp_content_type("text/plain")
    |> send_resp(200, "Hello, here is your #{id}")
  end

  def delete_repository(conn, %{"repository" => _repository}) do
    conn
    |> send_resp(200, "OK")
  end
end

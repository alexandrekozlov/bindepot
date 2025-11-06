defmodule BindepotWeb.Api.RepositoryController do
  use BindepotWeb, :controller

  import Ecto.Query
  alias Bindepot.Core.Asset
  alias Bindepot.Core.Assets
  alias Bindepot.Core.Repositories
  alias Bindepot.Core.Repository

  def list_repositories(conn, _params) do
    body =
      Repositories.all()
      |> sanitize_schema()
      |> Jason.encode!(pretty: true)

    conn
    |> put_resp_content_type("application/json")
    |> send_resp(200, body)
  end

  def create_repository(conn, %{"name" => repository_name} = params) do
    result =
      params
      |> Map.put("repository_name", repository_name)
      |> Map.put_new("repository_type", "local")
      |> Map.put_new("package_type", "generic")
      |> Repositories.create()

    resp =
      case result do
        {:ok, repo} ->
          %{
            :id => repo.id,
            :result => 200,
            :message => "Created",
            :repository =>
              repo
              |> sanitize_schema()
          }

        {:error, %Ecto.Changeset{} = changeset} ->
          %{
            :result => 400,
            :message => "Failed to create repository",
            :errors => extract_errors(changeset)
          }

        {:error, reason} ->
          %{
            :result => 400,
            :message => reason
          }
      end

    conn
    |> put_resp_content_type("application/json")
    |> send_resp(resp.result, Jason.encode!(resp, pretty: true))
  end

  def delete_repository(conn, %{"id" => id}) do
    repo = Repositories.get(id)

    resp =
      case Repositories.delete(repo) do
        {:ok, _r} ->
          %{
            :id => id,
            :result => 200,
            :message => "Deleted"
          }

        {:error, changeset} ->
          %{
            :id => id,
            :result => 404,
            :message => "failed to delete repository",
            :errors => extract_errors(changeset)
          }
      end

    conn
    |> put_resp_content_type("application/json")
    |> send_resp(resp.id, Jason.encode!(resp, pretty: true))
  end

  def list_assets(conn, _params) do
    assets = Assets.all()

    resp =
      Enum.map(assets, fn x ->
        %{
          repository: x.repository.name,
          name: x.name
        }
      end)

    IO.inspect(resp)

    conn
    |> put_resp_content_type("application/json")
    |> send_resp(200, Jason.encode!(resp, pretty: true))
  end

  def upload(conn, %{"name" => repo_name, "path" => path} = _params) do
    repo = Repositories.get_by_name(repo_name)

    rel_artifact_path =
      path
      |> Path.join()
      |> Path.expand("/")

    temp =
      Temp.open!(nil, fn file ->
        read_request_body(conn, file)
      end)

    {:ok, asset} = Assets.put(repo, rel_artifact_path, temp)
    File.rm(temp)

    resp = %{
      "path" => asset.name
    }

    conn
    |> put_resp_content_type("application/json")
    |> send_resp(200, Jason.encode!(resp, pretty: true))
  end

  def download(conn, %{"name" => repo_name, "path" => path} = _params) do
    rel_artifact_path =
      path
      |> Path.join()
      |> Path.expand("/")

    {:ok, file_path} = Assets.get(from a in Asset, where: a.name == ^rel_artifact_path)

    send_download(conn, {:file, file_path},
      filename: Path.basename(rel_artifact_path),
      disposition: :attachment
    )
  end

  defp read_request_body(conn, file) do
    case read_body(conn) do
      {:ok, body, conn} ->
        IO.binwrite(file, body)
        {:ok, conn}

      {:more, body, conn} ->
        IO.binwrite(file, body)
        read_request_body(conn, file)
        {:ok, conn}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp sanitize_schema(list) when is_list(list) do
    f = fn e ->
      Map.from_struct(e)
      |> Map.delete(:__meta__)
    end

    Enum.map(list, f)
  end

  defp sanitize_schema(%Repository{} = repo) do
    repo
    |> Map.from_struct()
    |> Map.delete(:__meta__)
  end

  defp extract_errors(%Ecto.Changeset{} = changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {msg, _opts} ->
      msg
    end)
  end
end

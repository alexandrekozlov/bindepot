defmodule BindepotWeb.Api.RepositoryController do
  use BindepotWeb, :controller

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

  def list_deleted(conn, _params) do
    body =
      Repositories.all_deleted()
      |> sanitize_schema()
      |> Jason.encode!(pretty: true)

    conn
    |> put_resp_content_type("application/json")
    |> send_resp(200, body)
  end

  def create_repository(conn, %{"name" => name} = params) do
    result =
      params
      |> Map.put("name", name)
      |> Map.put_new("type", "local")
      |> Map.put_new("package_type", "generic")
      |> IO.inspect()
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

  def delete_repository(conn, %{"name" => name}) do
    repo = Repositories.get_by_name(name)

    resp =
      case Repositories.delete(repo.id) do
        {:ok, _r} ->
          %{
            :id => repo.id,
            :name => repo.name,
            :result => 200,
            :message => "Deleted"
          }

        {:error, changeset} ->
          %{
            :id => repo.id,
            :name => repo.name,
            :result => 404,
            :message => "failed to delete repository",
            :errors => extract_errors(changeset)
          }
      end

    conn
    |> put_resp_content_type("application/json")
    |> send_resp(resp.result, Jason.encode!(resp, pretty: true))
  end

  def purge_repository(conn, %{"id" => id}) do
    repo = Repositories.get_deleted(id)

    resp =
      case Repositories.purge(repo.id) do
        {:ok, _r} ->
          %{
            :id => repo.id,
            :name => repo.name,
            :result => 200,
            :message => "Purged"
          }

        {:error, changeset} ->
          %{
            :id => repo.id,
            :name => repo.name,
            :result => 404,
            :message => "failed to purge repository",
            :errors => extract_errors(changeset)
          }
      end

    conn
    |> put_resp_content_type("application/json")
    |> send_resp(resp.result, Jason.encode!(resp, pretty: true))
  end

  defp sanitize_schema(list) when is_list(list) do
    f = fn e ->
      Map.from_struct(e)
      |> remove_not_loaded_associations()
      |> Map.delete(:__meta__)
    end

    Enum.map(list, f)
  end

  defp sanitize_schema(%Repository{} = repo) do
    repo
    |> Map.from_struct()
    |> remove_not_loaded_associations()
    |> Map.delete(:__meta__)
  end

  defp remove_not_loaded_associations(map) do
    map
    |> Enum.reduce(%{}, fn {key, value}, acc ->
      if is_struct(value, Ecto.Association.NotLoaded) do
        acc
      else
        Map.put(acc, key, value)
      end
    end)
  end

  defp extract_errors(%Ecto.Changeset{} = changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {msg, _opts} ->
      msg
    end)
  end
end

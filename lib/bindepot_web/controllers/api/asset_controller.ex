defmodule BindepotWeb.Api.AssetController do
  use BindepotWeb, :controller

  import Ecto.Query
  alias Bindepot.Core.Asset
  alias Bindepot.Core.Assets
  alias Bindepot.Core.Repositories
  alias Bindepot.Core.Repository

  def list(conn, %{"repo" => repo_key} = _params) do
    repo = Repositories.get_by_name(repo_key)
    assets = Assets.all(repo)

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

  def upload(conn, %{"repo" => repo_name, "path" => path}) do
    repo = Repositories.get_by_name(repo_name)

    rel_artifact_path =
      path
      |> Path.join()
      |> Path.expand("/")

    asset_dir = Path.dirname(rel_artifact_path)
    asset_file = Path.basename(rel_artifact_path)

    stream = request_body_stream(conn)
    {:ok, asset} = Assets.put_stream(repo.id, asset_file, asset_dir, stream)

    resp = sanitize_schema(asset)

    conn
    |> put_resp_content_type("application/json")
    |> send_resp(200, Jason.encode!(resp, pretty: true))
  end

  def download(conn, %{"repo" => repo_name, "path" => path} = _params) do
    rel_artifact_path =
      path
      |> Path.join()
      |> Path.expand("/")

    q =
      from a in Asset,
        join: r in Repository,
        on: r.id == a.repository_id,
        where: r.name == ^repo_name,
        where: a.name == ^rel_artifact_path

    {:ok, file_path} = Assets.get(q)

    send_download(conn, {:file, file_path},
      filename: Path.basename(rel_artifact_path),
      disposition: :attachment
    )
  end

  defp request_body_stream(conn) do
    Stream.resource(
      fn ->
        {:ok, conn}
      end,
      fn state ->
        case state do
          {:ok, conn} ->
            case read_body(conn) do
              {:ok, body, conn} ->
                {[body], {:halt, conn}}

              {:more, body, conn} ->
                {[body], {:ok, conn}}

              {:error, _reason} ->
                {:halt, {:error, conn}}
            end

          {:halt, conn} ->
            {:halt, conn}
        end
      end,
      fn _state ->
        :ok
      end
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
      |> remove_not_loaded_associations()
      |> Map.delete(:__meta__)
    end

    Enum.map(list, f)
  end

  defp sanitize_schema(%Asset{} = repo) do
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

defmodule BindepotWeb.Api.AssetController do
  use BindepotWeb, :controller

  alias Bindepot.Core.Assets
  alias Bindepot.Core.Repositories

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

    stream = request_body_stream(conn)
    {:ok, asset} = Assets.put_stream(repo.id, rel_artifact_path, stream)
    x = elem(List.first(asset), 1) |> IO.inspect(asset)

    resp = sanitize_schema(x)

    conn
    |> put_resp_content_type("application/json")
    |> send_resp(200, Jason.encode!(resp, pretty: true))
  end

  def download(conn, %{"repo" => repo_name, "path" => path} = _params) do
    rel_artifact_path =
      path
      |> Path.join()
      |> Path.expand("/")

    repo = Repositories.get_by_name(repo_name)
    {:ok, file_path} = Assets.get(repo.id, rel_artifact_path)

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

  defp sanitize_schema(repo) when is_struct(repo) do
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

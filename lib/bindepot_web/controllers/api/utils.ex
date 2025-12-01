defmodule BindepotWeb.Api.Utils do
  alias Plug.Conn

  def send_chunked_stream(conn, filename, stream) do
    conn
    |> Conn.put_resp_header(
      "content-disposition",
      "attachment; filename=\"#{filename}\""
    )
    |> Conn.send_chunked(200)
    |> then(fn c ->
      Enum.reduce(stream, c, fn chunk, acc_conn ->
        case Plug.Conn.chunk(acc_conn, chunk) do
          {:ok, new_conn} -> new_conn
          {:error, :closed} -> acc_conn
        end
      end)
    end)
  end

  def request_body_as_stream(conn) do
    Stream.resource(
      fn ->
        {:ok, conn}
      end,
      fn state ->
        case state do
          {:ok, conn} ->
            case Conn.read_body(conn) do
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

  def request_body_as_file(conn, file) do
    case Conn.read_body(conn) do
      {:ok, body, conn} ->
        IO.binwrite(file, body)
        {:ok, conn}

      {:more, body, conn} ->
        IO.binwrite(file, body)
        request_body_as_file(conn, file)
        {:ok, conn}

      {:error, reason} ->
        {:error, reason}
    end
  end

  def sanitize_schema(list) when is_list(list) do
    f = fn e ->
      Map.from_struct(e)
      |> remove_not_loaded_associations()
      |> Map.delete(:__meta__)
    end

    Enum.map(list, f)
  end

  def sanitize_schema(repo) when is_struct(repo) do
    repo
    |> Map.from_struct()
    |> remove_not_loaded_associations()
    |> remove_meta()

    # |> Map.delete(:__meta__)
  end

  defp remove_meta(map) do
    Enum.reduce(map, %{}, fn {key, value}, acc ->
      cond do
        key == :__meta__ ->
          acc

        is_map(value) ->
          Map.put(acc, key, remove_meta(value))

        true ->
          Map.put(acc, key, value)
      end
    end)
  end

  defp remove_not_loaded_associations(map) do
    map
    |> Enum.reduce(%{}, fn {key, value}, acc ->
      if is_struct(value, Ecto.Association.NotLoaded) do
        acc
      else
        if is_struct(value) do
          v =
            Map.from_struct(value)
            |> remove_not_loaded_associations()

          Map.put(acc, key, v)
        else
          Map.put(acc, key, value)
        end
      end
    end)
  end
end

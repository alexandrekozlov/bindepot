defmodule Bindepot.Pypi.RepoIndex do
  alias Bindepot.Core.Packages
  alias Bindepot.Core.DistFiles
  alias Bindepot.Pypi.HtmlIndexParser

  @etag_header "etag"
  @is_none_match_header "If-None-Match"

  @doc ~S"""
  Fetches and parses PyPI repository index from remote repository.

  `etag` specifies HTTP ETag header value.

  Returns
    * `{:ok, %{status: :new, etag: etag, items: items}}` - index was retrieved and parsed
    * `{:ok, status: :unchanged }` - index has not changed
    * `{:ok, status: http_result }` - other than HTTP 200 or 304 result returned
    * `{:error, reason }` - other, non-HTTP error occurred.


  """
  def get_remote_index(url, etag \\ nil) do
    stream_handler = fn
      {:status, 200}, acc ->
        {:cont, Map.put(acc, :status, :new)}

      {:status, 304}, acc ->
        {:cont, Map.put(acc, :status, :unchanged)}

      {:status, status}, acc ->
        {:halt, Map.put(acc, :status, status)}

      {:headers, headers}, acc ->
        {:cont, Map.put(acc, :etag, get_etag(headers))}

      {:data, data}, acc ->
        buffer = acc.tail <> data
        {items, tail} = HtmlIndexParser.parse_buffer(buffer, acc.items)
        {:cont, %{acc | items: items, tail: tail}}

      {:trailers, trailers}, acc ->
        {:cont, Map.put(acc, :etag, get_etag(trailers))}
    end

    etag_header = if is_nil(etag), do: [], else: [{@is_none_match_header, etag}]

    Finch.build(:get, url, etag_header)
    |> Finch.stream_while(Bindepot.Finch, %{items: %{}, tail: ""}, stream_handler)
    |> then(&{elem(&1, 0), Map.delete(elem(&1, 1), :tail)})
  end

  def get_remote_repo_index(repository_id) do
    repo = Bindepot.Core.Repositories.get(repository_id)
    node = Bindepot.Core.Nodes.get(repository_id, "/.pypi/index.json")
    etag = get_node_etag(node)

    url =
      repo.url
      |> URI.parse()
      |> URI.append_path("/simple/")

    case get_remote_index(url, etag) do
      {:ok, %{status: :new, etag: etag, items: items}} ->
        Bindepot.Core.Assets.put_stream(
          repository_id,
          "/.pypi/index.json",
          [Jason.encode!(items)],
          replace: true,
          properties: %{"etag" => etag}
        )

        {:ok, items}

      {:ok, %{status: :unchanged}} ->
        items =
          Bindepot.Core.Assets.get_stream(repository_id, "/.pypi/index.json")
          |> Enum.into("")
          |> Jason.decode!()

        {:ok, items}

      {:ok, %{status: result}} when is_integer(result) ->
        {:error, "HTTP result: #{result}"}

      {:error, reason} ->
        {:error, reason}

      _ ->
        {:error, "unexpected error"}
    end
  end

  def get_remote_package_index(repository_id, package_url) do
    repo = Bindepot.Core.Repositories.get(repository_id)

    url =
      repo.url
      |> URI.parse()
      |> URI.merge(package_url)

    case get_remote_index(url) do
      {:ok, %{status: :new, etag: _etag, items: items}} ->
        {:ok, items}

      {:ok, %{status: result}} when is_integer(result) ->
        {:error, "HTTP result: #{result}"}

      {:error, reason} ->
        {:error, reason}

      _ ->
        {:error, "unexpected error"}
    end
  end

  defp get_node_etag(node) do
    case node do
      nil ->
        nil

      node ->
        Bindepot.Core.NodeProperties.get_property(node, "etag")
    end
  end

  def get_local_repo_index(repository_id) do
    repository_id
    |> Packages.all()
    |> Enum.map(&%{name: &1.name, uri: &1.name <> "/"})
    |> Enum.sort(&(&1.name >= &2.name))
  end

  def get_local_package_index(repository_id, package_name) do
    repository_id
    |> DistFiles.all(package_name)
    |> Enum.map(&%{name: &1.name, uri: &1.name, hash: {"sha256", &1.blob.sha256}})
    |> Enum.sort(&(&1.name >= &2.name))
  end

  def extract_repo_index(stream) do
    stream
    |> HtmlIndexParser.parse()
    |> Enum.reduce([], fn element, acc ->
      [%{name: element.content, uri: element.href} | acc]
    end)
  end

  defp get_etag(headers) do
    Enum.find_value(headers, nil, &if(elem(&1, 0) == @etag_header, do: elem(&1, 1)))
  end
end

defmodule Bindepot.Pypi.RepoIndex do
  alias Bindepot.Core.Packages
  alias Bindepot.Core.DistFiles
  alias Bindepot.Pypi.HtmlIndexParser

  @etag_header "etag"
  @is_none_match_header "If-None-Match"

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

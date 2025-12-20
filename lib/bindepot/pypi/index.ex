defmodule Bindepot.Pypi.Index do
  alias Bindepot.Core.Assets
  alias Bindepot.Core.Nodes
  alias Bindepot.Pypi.HtmlIndexParser

  # @cached_repo_index_path "/.pypi/index.html"
  @etag_header "etag"
  @is_none_match_header "If-None-Match"

  def fetch_remote_repo_index2(repo_index_url, etag \\ nil) do
    etag_header = if is_nil(etag), do: [], else: [{@is_none_match_header, etag}]
    Req.get(repo_index_url, headers: etag_header)
  end

  @doc """
    Gets and caches the remote repository PyPI index.

    `repository_id` - location where the index is to be cached.

  """
  def fetch_remote_repo_index(repository_id, repo_index_url, store_path) do
    node = Nodes.get_file(repository_id, store_path)

    headers =
      if is_nil(node) do
        []
      else
        # TODO: check node exists
        etag =
          Jason.decode!(node.properties || "{}")
          |> Map.get(@etag_header)

        if is_nil(etag) do
          []
        else
          [{@is_none_match_header, etag}]
        end
      end
      |> IO.inspect()

    resp =
      Finch.build(:get, repo_index_url, headers)
      |> Finch.request!(Bindepot.Finch)
      |> IO.inspect()

    index_file = Temp.path!()
    cache_index(resp, repository_id, store_path, index_file)
    HtmlIndexParser.parse(File.stream!(index_file, 65536))
  end

  defp cache_index(%{status: 304} = _resp, repository_id, store_path, index_file) do
    Assets.get_file(repository_id, store_path, index_file)
  end

  defp cache_index(%{status: 200} = resp, repository_id, store_path, index_file) do
    File.write!(index_file, resp.body, [:binary, :write])

    etag = Enum.find_value(resp.headers, nil, &if(elem(&1, 0) == @etag_header, do: elem(&1, 1)))

    Assets.put_file(repository_id, store_path, index_file,
      properties: Jason.encode!(%{etag: etag}),
      replace: true,
      keep_source: true
    )
  end
end

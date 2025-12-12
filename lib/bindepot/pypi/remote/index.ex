defmodule Bindepot.Pypi.Remote.Index do
  alias Bindepot.Core.Assets
  alias Bindepot.Core.Nodes

  @cached_repo_index_path "/.pypi/index.html"
  @etag_header "etag"
  @is_none_match_header "If-None-Match"

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
      Finch.build(
        :get,
        # TODO: Get URL from repo or better from argument.
        # the reason to take from argument, even though we already have repo is
        # that it allows us to have a choice where to store the cached index.
        # It can either be stored in the remote repo itself (/.pypi/index)
        # or stored in a dedicated local repository that deals with cache only.
        repo_index_url,
        headers
      )
      |> Finch.request!(Bindepot.Finch)
      |> IO.inspect()

    index_file = Temp.path!()
    cache_index(resp, repository_id, store_path, index_file)
    Bindepot.Pypi.HtmlIndexParser.extract(File.stream!(index_file, 65536, encoding: :latin1))
  end

  def cache_index(%{status: 304} = _resp, repository_id, store_path, index_file) do
    Assets.get_file(repository_id, store_path, index_file)
  end

  def cache_index(%{status: 200} = resp, repository_id, store_path, index_file) do
    File.write!(index_file, resp.body, [:binary, :write])

    etag = Enum.find_value(resp.headers, nil, &if(elem(&1, 0) == @etag_header, do: elem(&1, 1)))

    Assets.put_file(repository_id, store_path, index_file,
      properties: Jason.encode!(%{etag: etag}),
      replace: true,
      keep_source: true
    )
  end

  def merge_index(index1) do
    index1 |>
    Enum.into(%{}, &({&1.name, &1}))
    Map.merge()
  end

end

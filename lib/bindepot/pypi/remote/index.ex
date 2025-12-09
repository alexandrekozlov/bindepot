defmodule Bindepot.Pypi.Remote.Index do
  alias Bindepot.Core.Assets
  alias Bindepot.Core.Nodes

  @cached_repo_index_path "/.pypi/index.html"

  def get_remote_index(repository_id) do
    node = Nodes.get_file(repository_id, @cached_repo_index_path)

    headers =
      if is_nil(node) do
        []
      else
        # TODO: check node exists
        etag =
          Jason.decode!(node.properties || "{}")
          |> Map.get("etag")

        if is_nil(etag) do
          []
        else
          [{"If-None-Match", etag}]
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
        "https://pypi.org/simple/",
        headers
      )
      |> Finch.request!(Bindepot.Finch)

    index_file = Temp.path!()

    case resp.status do
      # Not modified
      304 ->
        Assets.get_file(repository_id, @cached_repo_index_path, index_file)

      # OK
      200 ->
        File.write!(index_file, resp.body, [:binary, :write])

        etag =
          Enum.find_value(resp.headers, nil, &(if elem(&1, 0) == "etag", do: elem(&1, 1)))
          |> IO.inspect(label: "etag")

        Assets.put_file(repository_id, @cached_repo_index_path, index_file,
          properties: Jason.encode!(%{etag: etag}),
          replace: true
        )
    end
  end
end

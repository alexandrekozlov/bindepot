defmodule Bindepot.Pypi.RepoIndex do
  require Logger
  alias Logger

  alias Bindepot.Core.Repositories
  alias Bindepot.Core.Packages
  alias Bindepot.Core.DistFiles
  alias Bindepot.Pypi.HtmlIndexParser

  @etag_header "etag"
  @is_none_match_header "If-None-Match"

  @doc ~S"""
  Fetches repository index according to the repository settings.

  The result is not sorted.

  For remote repositories the result is cached if possible.

  Returns:
    * `{:ok, items}` - index
    * `{:error, reason}` - error

  where `items` are in the following format:

  ```
  [
    %{ name: project_name, uri: project_uri },
    ...
  ]
  ```

  """
  def get_repo_index(%{type: "local", id: id} = _repository) do
    {:ok,
     id
     |> Packages.all()
     |> Enum.map(fn e -> %{name: e.name, uri: e.name <> "/"} end)}
  end

  def get_repo_index(%{type: "remote", id: id} = repository) do
    Logger.debug("get_repo_index (remote)")

    node = Bindepot.Core.Nodes.get(id, "/.pypi/index.json")
    etag = get_node_etag(node)

    url =
      repository.url
      |> URI.parse()
      |> URI.append_path("/simple/")

    Logger.debug("fetching remote repo index from #{url}")

    case fetch_index(url, etag) do
      {:ok, %{status: :new, etag: etag, items: items}} ->
        Bindepot.Core.Assets.put_stream(
          id,
          "/.pypi/index.json",
          [Jason.encode_to_iodata!(items)],
          replace: true,
          properties: %{"etag" => etag}
        )

        {:ok, items}

      {:ok, %{status: :unchanged}} ->
        items =
          Bindepot.Core.Assets.get_stream(id, "/.pypi/index.json")
          |> Enum.into("")
          |> Jason.decode!(keys: &key_decoder(&1))

        Logger.debug("Finished decoding cached index")
        {:ok, items}

      {:ok, %{status: result}} when is_integer(result) ->
        {:error, "HTTP result: #{result}"}

      {:error, reason} ->
        {:error, reason}

      _ ->
        {:error, "unexpected error"}
    end
  end

  def get_repo_index(%{type: "virtual", repositories: children} = _repository) do
    {:ok,
     children
     |> Enum.flat_map(fn key ->
       key
       |> Repositories.get_by_name()
       |> get_repo_index()
       |> then(fn {:ok, idx} -> idx end)
       |> Enum.map(fn %{name: n} -> {n, %{name: n, uri: n <> "/"}} end)
     end)
     |> Map.new()
     |> Map.values()}
  end

  def get_project_index(%{type: "local", id: id, name: name} = _repository, project_name) do
    id
    |> DistFiles.files(project_name)
    |> Enum.map(
      &%{
        repository: name,
        name: &1.name,
        uri: "#{&1.path}/#{&1.name}",
        hash: {"sha256", &1.blob.sha256},
        metadata: %{}
      }
    )
  end

  @doc ~S"""
    Gets remote project index.

  """
  def get_project_index(%{type: "remote"} = repository, project_name) do
    # TODO: Can we optimize here? We fetch the whole index (pypi.org is the worst case)
    # just to figure the projet URL. Can we first try to get the remote project index
    # by just composing a url and if this does not work, fall back
    # into retrieving the whole index to figure the project URL.

    # An important behavior was discovered with help of Claude - Artifactory hardcodes
    # the virtual repo resolution order - local, remote-cache, remote.
    # The order is respected WITHIN each repo type.
    # Also, Nexus does not do that and resolves in order given, irrespective repo type.
    {:ok, repo_index} = get_repo_index(repository)

    case Enum.find(repo_index, nil, fn x -> x.name == project_name end) do
      nil ->
        []

      %{uri: url} ->
        {:ok, projects} = get_remote_project_index(repository, url)
        projects
    end
  end

  def get_project_index(%{type: "virtual", repositories: children}, project_name) do
    # TODO: We can probably cache part and full index here.
    children
    |> Enum.flat_map(fn key ->
      key
      |> Repositories.get_by_name()
      |> get_project_index(project_name)
      |> Enum.map(fn %{repository: repo_name, name: n} = proj ->
        {n,
         %{
           repository: repo_name,
           name: n,
           uri: proj.uri,
           hash: proj.hash,
           metadata: proj.metadata
         }}
      end)
    end)
    |> Map.new()
    |> Map.values()
  end

  defp get_remote_project_index(repository, project_url) do
    url =
      repository.url
      |> URI.parse()
      |> URI.merge(project_url)

    case fetch_index(url) do
      {:ok, %{status: :new, etag: _etag, items: projects}} ->
        {:ok, Enum.map(projects, fn p -> Map.put(p, :repository, repository.name) end)}

      {:ok, %{status: result}} when is_integer(result) ->
        {:error, "HTTP result: #{result}"}

      {:error, reason} ->
        {:error, reason}

      _ ->
        {:error, "unexpected error"}
    end
  end

  # Fetches and parses PyPI repository index from specified URL.
  #
  # `etag` specifies HTTP ETag header value.
  #
  # The index items have the structure:
  # ```
  # %{
  #   uri: "uri",
  #   name: "name",
  #   metadata: %{ "key" => "value" },
  #   hash: { "algo", "digest" }
  # }
  # ```
  #
  # Returns
  #   * `{:ok, %{status: :new, etag: etag, items: items}}` - index was retrieved and parsed
  #   * `{:ok, status: :unchanged }` - index has not changed
  #   * `{:ok, status: http_result }` - other than HTTP 200 or 304 result returned
  #   * `{:error, reason }` - other, non-HTTP error occurred.
  defp fetch_index(url, etag \\ nil) do
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
    |> Finch.stream_while(Bindepot.Finch, %{items: [], tail: ""}, stream_handler)
    |> then(&{elem(&1, 0), Map.delete(elem(&1, 1), :tail)})
  end

  defp get_node_etag(node) do
    case node do
      nil ->
        nil

      node ->
        Bindepot.Core.NodeProperties.get_property(node, "etag")
    end
  end

  defp get_etag(headers) do
    Enum.find_value(headers, nil, &if(elem(&1, 0) == @etag_header, do: elem(&1, 1)))
  end

  # This decoder is used by JSON decoder and ensures only known keys are decoded
  # as atoms, while others as strings.
  defp key_decoder(str) do
    case str do
      "uri" -> :uri
      "name" -> :name
      "metadata" -> :metadata
      "hash" -> :hash
      _ -> str
    end
  end

  def measure(function) do
    r =
      function
      |> :timer.tc()

    r
    |> elem(0)
    |> Kernel./(1_000_000)
    |> then(&IO.puts("#{&1}"))

    elem(r, 1)
  end

  def measure_silent(function) do
    r =
      function
      |> :timer.tc()

    r
    |> elem(0)
    |> Kernel./(1_000_000)
    |> then(&IO.puts("#{&1}"))
  end
end

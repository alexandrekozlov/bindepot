defmodule Bindepot.Core.Nodes do
  alias Bindepot.Core.Node

  def mkdir(repository_id, path) do
    changesets =
      path
      |> String.split("/", trim: true)
      |> nodes_from_path()
      |> Enum.scan(nil, fn n, _ ->
        %{type: 0, path: elem(n, 0), name: elem(n, 1), repository_id: repository_id}
      end)
      |> Enum.reverse()
      |> Enum.scan(nil, fn n, _ ->
        Node.changeset(%Node{}, n)
      end)

    changesets
  end

  def generate_nodes(repository_id, path, blob_id \\ nil) do
    nodes =
      path
      |> String.split("/", trim: true)
      |> nodes_from_path()
      |> Enum.scan(nil, fn n, _a ->
        %{type: 0, path: elem(n, 0), name: elem(n, 1), repository_id: repository_id}
      end)

    case nodes do
      [] ->
        []

      [last | rest] when is_nil(blob_id) ->
        [last | rest] |> Enum.reverse()

      [last | rest] ->
        [Map.put(last, :blob_id, blob_id) | rest] |> Enum.reverse()
    end
  end

  @doc """
    Create node elements from path.

    Returns list of tuples `{ parent_path, name }`. The tuples arranged from
    child to parent, which makes it convenient to modify the last path element
    depending on whether it is a file or a directory.
  """
  def nodes_from_path(path, parent \\ nil, nodes \\ []) do
    cond do
      # Empty path
      path == [] ->
        []

      # single element path
      is_nil(parent) && length(path) == 1 ->
        [{"/", hd(path)}]

      # first element
      is_nil(parent) ->
        nodes_from_path(tl(path), "/" <> hd(path), [{"/", hd(path)} | nodes])

      # last element
      length(path) == 1 ->
        [{parent, hd(path)} | nodes]

      # any other element
      true ->
        nodes_from_path(tl(path), parent <> "/" <> hd(path), [{parent, hd(path)} | nodes])
    end
  end
end

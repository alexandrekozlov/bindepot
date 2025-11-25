defmodule Bindepot.Core.Nodes do
  alias Bindepot.Repo
  alias Bindepot.Core.Node

  # TODO: Cannot just insert as the node may already exist
  def create_directory(repository_id, path) do
    create_node_entries(path, repository_id)
    |> Enum.scan(nil, fn n, _a -> %Node{} |> Node.changeset(n) end)
    |> Enum.reverse()
    |> Enum.each(&Repo.insert(&1))
  end

  def create_file(repository_id, path, blob_id) do
    create_node_entries(path, repository_id)
    |> Enum.scan(nil, fn n, _a -> %Node{} |> Node.changeset(n) end)
    |> then(fn [file_node | rest] ->
      [%{file_node | type: 1} |> Map.put(:blob_id, blob_id) | rest]
    end)
    |> Enum.scan(nil, fn n, _a -> %Node{} |> Node.changeset(n) end)
    |> Enum.reverse()
    |> Enum.each(&Repo.insert(&1))
  end

  @doc """
    Create node elements from path.

    Returns list of tuples `{ parent_path, name }`. The tuples arranged from
    child to parent, which makes it convenient to modify the last path element
    depending on whether it is a file or a directory.
  """
  def nodes_from_path(path) do
    path
    |> String.split("/", trim: true)
    |> do_nodes_from_path()
  end

  defp create_node_entries(path, repository_id) do
    path
    |> nodes_from_path()
    |> Enum.scan(nil, fn n, _a ->
      %{type: 0, path: elem(n, 0), name: elem(n, 1), repository_id: repository_id}
    end)
  end

  defp do_nodes_from_path(path, parent \\ nil, nodes \\ []) do
    cond do
      # Empty path
      path == [] ->
        []

      # single element path
      is_nil(parent) && length(path) == 1 ->
        [{"/", hd(path)}]

      # first element
      is_nil(parent) ->
        do_nodes_from_path(tl(path), "/" <> hd(path), [{"/", hd(path)} | nodes])

      # last element
      length(path) == 1 ->
        [{parent, hd(path)} | nodes]

      # any other element
      true ->
        do_nodes_from_path(tl(path), parent <> "/" <> hd(path), [{parent, hd(path)} | nodes])
    end
  end
end

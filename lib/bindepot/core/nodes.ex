defmodule Bindepot.Core.Nodes do
  import Ecto.Query

  alias Bindepot.Core.NodeProperties
  alias Bindepot.Repo
  alias Bindepot.Core.Node

  def all(repository_id, path, opts \\ []) do
    repository_id
    |> Node.all(path, Keyword.get(opts, :recursive, false))
    |> Repo.all()
  end

  def empty?(repository_id, path) do
    repository_id
    |> Node.all(path)
    |> select(count())
    |> Repo.one() == 0
  end

  def get(repository_id, path) do
    case parse_path(path) do
      {"/", nil} ->
        :root

      {p, n} ->
        Node
        |> Repo.get_by(repository_id: repository_id, path: p, name: n)
        |> Repo.preload(:blob)
    end
  end

  @doc """
  Gets all files recursively.
  """
  def get_files(repository_id) do
    Repo.all_by(Node, repository_id: repository_id, type: :file)
  end

  def get_file(repository_id, path) do
    case List.first(items_from_path(path)) do
      nil ->
        nil

      {path, name} ->
        Repo.get_by(Node, repository_id: repository_id, type: :file, path: path, name: name)
    end
  end

  @doc ~S"""
  Creates a directory.

  Returns the last directory node.

  If directory already exists, then the function fails.

  Options:
    * `:properties` - map of name/values to attach
    * `:replace` - replaces existing directory.
  """
  @spec create_directory(any(), String.t(), properties: map(), replace: boolean()) ::
          {:ok, Node.t()} | {:error, String.t()}
  def create_directory(repository_id, path, opts \\ []) do
    case create_node_params(path, repository_id) do
      [] ->
        {:error, "effective path is empty"}

      [last_node | dir_nodes] ->
        create_intermediate_nodes(dir_nodes)
        props = Keyword.get(opts, :properties, %{})
        replace = Keyword.get(opts, :replace, false)
        create_terminal_node(last_node, replace, props)
    end
  end

  @doc ~S"""
  Creates a file.

  Returns a file node.

  If file already exists, then the function fails.

  Options:
    * `:properties` - map of name/values to attach
    * `:replace` - replaces existing file.
  """
  @spec create_file(any(), String.t(), any(), properties: map(), replace: boolean()) ::
          {:ok, Node.t()} | {:error, String.t()}
  def create_file(repository_id, path, blob_id, opts \\ []) do
    case create_node_params(path, repository_id) do
      [] ->
        {:error, "effective path is empty"}

      [last_node | dir_nodes] ->
        create_intermediate_nodes(dir_nodes)
        props = Keyword.get(opts, :properties, %{})
        replace = Keyword.get(opts, :replace, false)
        create_terminal_node(to_file_node(last_node, blob_id), replace, props)
    end
  end

  def parse_path(path) do
    items =
      path
      |> String.split("/", trim: true)
      |> Enum.reverse()

    case items do
      [] ->
        {"/", nil}

      [n] when length(n) == 1 ->
        {"/", n}

      [n | p] ->
        {p
         |> Enum.reverse()
         |> Enum.join("/")
         |> then(fn p -> "/" <> p end), n}
    end
  end

  @doc """
  Creates items from path.

  Returns list of tuples `{ parent_path, child }`. The tuples arranged from
  child to parent, which makes it convenient to modify the last path element
  depending on whether it is a file or a directory.
  """
  def items_from_path(path) do
    path |> String.split("/", trim: true) |> do_items_from_path()
  end

  defp to_file_node(node, blob_id) do
    node
    |> Map.put(:type, :file)
    |> Map.put(:blob_id, blob_id)
  end

  defp create_node_params(path, repository_id) do
    path
    |> items_from_path()
    |> Enum.scan(nil, fn n, _a ->
      %{type: :directory, path: elem(n, 0), name: elem(n, 1), repository_id: repository_id}
    end)
  end

  defp get_existing_node(node_attr) do
    Repo.get_by(Node,
      path: node_attr.path,
      name: node_attr.name,
      repository_id: node_attr.repository_id
    )
  end

  defp create_intermediate_nodes(node_entries) do
    results =
      node_entries
      |> Enum.reverse()
      |> Enum.reduce([], &[create_intermediate_node(&1) | &2])

    case Enum.find(results, fn
           :ok -> false
           _ -> true
         end) do
      nil -> List.first(results)
      error_node -> error_node
    end
  end

  defp create_intermediate_node(%{type: :directory} = node_attr) do
    case get_existing_node(node_attr) do
      %{type: :directory} = node ->
        {:ok, node}

      %{type: :file} ->
        {:error, "cannot create directory node. file node already exist"}

      nil ->
        create_node(node_attr)
    end
  end

  defp create_terminal_node(node_attr, replace, props) do
    existing_node = get_existing_node(node_attr)

    case {existing_node, node_attr.type, replace} do
      {%{}, _, false} ->
        {:error, "node already exists"}

      {%{type: :directory}, :directory, true} ->
        if empty?(existing_node.repository_id, existing_node.path) do
          Repo.delete(existing_node)
          create_node(node_attr, props)
        else
          {:error, "cannot replace non-empty directory"}
        end

      {%{type: :file}, :file, true} ->
        Repo.delete(existing_node)
        create_node(node_attr, props)

      {%{type: :file}, :directory, true} ->
        {:error, "cannot create directory node in place of file node"}

      {%{type: :directory}, :file, true} ->
        {:error, "cannot create file node in place of directory node"}

      {nil, _, _} ->
        create_node(node_attr, props)
    end
  end

  defp create_node(node_attr, props \\ nil) do
    with_props = fn n ->
      if is_nil(props) do
        n
      else
        Ecto.Changeset.put_assoc(n, :node_properties, NodeProperties.build_properties(props))
      end
    end

    %Node{}
    |> Node.changeset(node_attr)
    |> with_props.()
    |> Repo.insert()
  end

  defp do_items_from_path(path, parent \\ nil, nodes \\ []) do
    cond do
      # Empty path
      path == [] ->
        []

      # single element path
      is_nil(parent) && length(path) == 1 ->
        [{"/", hd(path)}]

      # first element
      is_nil(parent) ->
        do_items_from_path(tl(path), "/" <> hd(path), [{"/", hd(path)} | nodes])

      # last element
      length(path) == 1 ->
        [{parent, hd(path)} | nodes]

      # any other element
      true ->
        do_items_from_path(tl(path), parent <> "/" <> hd(path), [{parent, hd(path)} | nodes])
    end
  end
end

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

    Returns the last directory node. On error returns reason and all nodes as
    a third tuple element.

  """
  @spec create_directory(any(), String.t(), properties: map()) ::
          {:ok, Node.t()} | {:error, String.t(), any()}
  def create_directory(repository_id, path, opts \\ []) do
    case create_node_params(path, repository_id) do
      [] ->
        {:error, "effective path is empty", nil}

      [last_node | dir_nodes] ->
        apply_node_params(dir_nodes)
        create_or_replace_node(last_node, opts)
    end
  end

  @doc ~S"""
    Creates a file.

    Returns a file node.

    If file already exists, then the function fails.

    Options:
      `:properties` - map of name/values to attac
      `:replace` - replaces existing file node.
  """
  @spec create_file(any(), String.t(), any(), replace: boolean()) ::
          {:ok, Node.t()} | {:error, String.t(), any()}
  def create_file(repository_id, path, blob_id, opts \\ []) do
    case create_node_params(path, repository_id) do
      [] ->
        {:error, "effective path is empty", nil}

      [file_node | dir_nodes] ->
        apply_node_params(dir_nodes)
        create_or_replace_node(to_file_node(file_node, blob_id), opts)
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
    Create items from path.

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

  defp apply_node_params(_node_params, _opts \\ [])

  defp apply_node_params([] = node_params, _opts) when length(node_params) == 0 do
    {:error, "effective path is epmty", nil}
  end

  @spec apply_node_params([map()], keyword()) :: {:ok, Node.t()} | {:error, String.t()}
  defp apply_node_params(node_entries, opts) do
    results =
      node_entries
      |> Enum.reverse()
      |> Enum.reduce([], &[insert_or_update_node(&1, opts) | &2])

    case Enum.find(results, fn
           :ok -> false
           _ -> true
         end) do
      nil -> List.first(results)
      error_node -> error_node
    end
  end

  # opts:
  #   replace: true | false - when true allows node replacement.
  #           this applies only for file nodes and ignored for directories.
  # returns:
  #   { :ok, node } on success
  #   { :error, error } on failure
  defp insert_or_update_node(node_attributes, opts) do
    props = Keyword.get(opts, :properties) || %{}

    node =
      get_existing_node(node_attributes, opts)
      |> Repo.preload([:node_properties]) || %Node{}

    np = NodeProperties.build_properties(props)

    node
    |> Node.changeset(node_attributes)
    |> Ecto.Changeset.put_assoc(:node_properties, np)
    |> Repo.insert_or_update()
  end

  # opts:
  #   properties: map of properties to associate with the node
  #   replace: true | false - when true allows node replacement.
  #
  # returns:
  #   { :ok, node } on success
  #   { :error, error } on failure
  defp create_or_replace_node(node_attributes, opts) do
    props = Keyword.get(opts, :properties, %{})
    replace = Keyword.get(opts, :replace, false)

    existing_node =
      Repo.get_by(Node,
        path: node_attributes.path,
        name: node_attributes.name,
        repository_id: node_attributes.repository_id
      )

    create_file_node(node_attributes, existing_node, replace, props)
  end

  defp create_file_node(node_attr, existing_node, replace, props)

  # new node
  defp create_file_node(node_attributes, nil, _replace, props) do
    np = NodeProperties.build_properties(props)

    %Node{}
    |> Node.changeset(node_attributes)
    |> Ecto.Changeset.put_assoc(:node_properties, np)
    |> Repo.insert()
  end

  # replace existing directory node
  defp create_file_node(node_attributes, %{type: :directory} = node, true, props) do
    case empty?(node.repository_id, node.path) do
      true ->
        Repo.delete(node)
        np = NodeProperties.build_properties(props)

        %Node{}
        |> Node.changeset(node_attributes)
        |> Ecto.Changeset.put_assoc(:node_properties, np)
        |> Repo.insert()

      false ->
        {:error, "directory is not empty", node}
    end
  end

  defp create_file_node(node_attributes, %{type: :file} = node, true, props) do
    Repo.delete(node)

    np = NodeProperties.build_properties(props)

    %Node{}
    |> Node.changeset(node_attributes)
    |> Ecto.Changeset.put_assoc(:node_properties, np)
    |> Repo.insert()
  end

  # node exists and cannot be replaced
  defp create_file_node(_, %{type: :file} = node, false, _) do
    {:error, "node already exists", node}
  end

  # a directory node cannot be replaced with a file node
  defp create_file_node(_, %{type: :directory} = node, _, _) do
    {:error, "cannot replace with a different node type", node}
  end

  # opts:
  #   replace: true | false - when true allows node replacement.
  #           this applies only for file nodes and ignored for directories.
  defp get_existing_node(node_attributes, opts) do
    if Keyword.get(opts, :replace, false) and node_attributes.type == :file do
      Repo.get_by(Node, Map.drop(node_attributes, [:blob_id]))
    else
      Repo.get_by(Node, node_attributes)
    end
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

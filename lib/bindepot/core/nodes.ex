defmodule Bindepot.Core.Nodes do
  alias Bindepot.Repo
  alias Bindepot.Core.Node

  def all(repository_id, path) do
    path
    |> String.split("/", trim: true)
    |> Enum.join("/")
    |> then(fn p -> "/" <> p end)
    |> then(&Repo.all_by(Node, repository_id: repository_id, path: &1))
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
  @spec create_directory(any(), String.t()) :: {:ok, Node.t()} | {:error, String.t(), any()}
  def create_directory(repository_id, path) do
    node_params =
      create_node_params(path, repository_id)

    case node_params do
      [] -> {:error, "effective path is epmty", nil}
      _ -> apply_node_params(node_params)
    end
  end

  @doc ~S"""
    Creates a file.

    Returns a file node.

    If file already exists, then the function fails. The existing file can be
    overwritten by specifying `replace` option.
  """
  @spec create_file(any(), String.t(), any(), replace: boolean()) ::
          {:ok, Node.t()} | {:error, String.t(), any()}
  def create_file(repository_id, path, blob_id, opts \\ []) do
    node_params =
      create_node_params(path, repository_id)

    case node_params do
      [] ->
        {:error, "effective path is epmty", nil}

      _ ->
        node_params
        |> then(fn [file_node | rest] ->
          [%{file_node | type: :file} |> Map.put(:blob_id, blob_id) | rest]
        end)
        |> apply_node_params(opts)
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

  defp create_node_params(path, repository_id) do
    path
    |> items_from_path()
    |> Enum.scan(nil, fn n, _a ->
      %{type: :directory, path: elem(n, 0), name: elem(n, 1), repository_id: repository_id}
    end)
  end

  @spec apply_node_params([map()], keyword()) :: {:ok, Node.t()} | {:error, String.t()}
  defp apply_node_params(node_entries, opts \\ []) do
    Repo.transact(fn ->
      results =
        node_entries
        |> Enum.reverse()
        |> Enum.reduce([], &[insert_or_update_node(&1, opts) | &2])

      case Enum.find(results, &(elem(&1, 0) != :ok)) do
        nil -> List.first(results)
        error_node -> error_node
      end
    end)
  end

  # opts:
  #   replace: true | false - when true allows node replacement.
  #           this applies only for file nodes and ignored for directories.
  defp insert_or_update_node(node_attributes, opts) do
    existing_node =
      if Keyword.get(opts, :replace, false) and node_attributes.type == :file do
        Repo.get_by(Node, Map.delete(node_attributes, :blob_id))
      else
        Repo.get_by(Node, node_attributes)
      end

    node = existing_node || %Node{}

    node
    |> Node.changeset(node_attributes)
    |> Repo.insert_or_update()
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

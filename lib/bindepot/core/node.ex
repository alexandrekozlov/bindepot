defmodule Bindepot.Core.Node do
  @moduledoc """
    Represents a node in file hierachy.
  """

  import Ecto.Changeset
  import Ecto.Query
  use Ecto.Schema
  import EctoEnum

  alias Bindepot.Core.Repository
  alias Bindepot.Core.DistFile
  alias Bindepot.Core.Blob

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  defenum(NodeType, directory: 0, file: 1)

  schema "nodes" do
    field :type, NodeType
    field :path, :string
    field :name, :string

    belongs_to :repository, Repository
    belongs_to :blob, Blob

    has_one :dist_file, DistFile

    has_many :node_properties, Bindepot.Core.NodeProperty
    has_many :properties, through: [:node_properties, :property]
  end

  @type t :: %__MODULE__{
          type: NodeType.t(),
          path: String.t(),
          name: String.t(),
          repository_id: term(),
          blob_id: term()
        }

  def changeset(struct, params) do
    struct
    |> cast(params, [
      :type,
      :path,
      :name,
      :repository_id,
      :blob_id
    ])
    |> assoc_constraint(:repository)
    |> validate_required([:type, :path, :name, :repository_id])
    |> validate_immutable([:type, :path, :name, :repository_id])
    |> unique_constraint([:type, :path, :name, :repository_id],
      name: :nodes_repository_id_type_path_name_index
    )
    |> validate_file_node()
  end

  def base() do
    Node
  end

  def by_path(query \\ base(), path) do
    where(query, [n], n.path == ^path)
  end

  # Verifies that file node (type: 1), has `blob_id` value.
  defp validate_file_node(changeset) do
    type = fetch_field!(changeset, :type)
    blob_id = fetch_field!(changeset, :blob_id)

    case {type, blob_id} do
      {:file, nil} -> add_error(changeset, :blob_id, "blob required for file node")
      _ -> changeset
    end
  end

  defp validate_immutable(changeset, fields) when is_list(fields) do
    Enum.reduce(fields, changeset, &validate_immutable_field(&2, &1))
  end

  defp validate_immutable_field(changeset, field) when is_atom(field) or is_binary(field) do
    current = Map.get(changeset.data, field, nil)
    new = fetch_change(changeset, field)

    case {current, new} do
      # should never happen as it will not pass validate_required
      {nil, :error} ->
        add_error(changeset, :type, "node #{field} is required")

      # either already set or new
      {_, :error} ->
        changeset

      {nil, {:ok, _}} ->
        changeset

      {c, {:ok, n}} when c != n ->
        add_error(changeset, :type, "#{field} once set is immutable")

      _ ->
        changeset
    end
  end
end

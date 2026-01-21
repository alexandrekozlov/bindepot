defmodule Bindepot.Core.NodeProperty do
  use Ecto.Schema
  import Ecto.Changeset

  alias Bindepot.Core.Node
  alias Bindepot.Core.Property

  # {:id, :binary_id, autogenerate: true}
  @primary_key false
  @foreign_key_type :binary_id

  schema "nodes_properties" do
    belongs_to :node, Node
    belongs_to :property, Property

    field :value, :string
  end

  def changeset(node_property, attrs) do
    node_property
    |> cast(attrs, [:node_id, :property_id, :value])
    |> cast_assoc(:node, required: false)
    |> cast_assoc(:property, required: false)
    |> validate_required([:value])
    |> unique_constraint([:node_id, :property_id])
    |> assoc_constraint(:node)
    |> assoc_constraint(:property)
  end
end

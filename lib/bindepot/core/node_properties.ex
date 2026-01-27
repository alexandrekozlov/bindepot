defmodule Bindepot.Core.NodeProperties do
  import Ecto.Query

  alias Bindepot.Repo

  alias Bindepot.Core.Node
  alias Bindepot.Core.NodeProperty
  alias Bindepot.Core.Properties
  alias Bindepot.Core.Property

  def build_properties(props) do
    Enum.map(props, fn {n, v} ->
      p = Properties.get_or_create_property(n)

      %NodeProperty{
        property_id: p.id,
        value: v
      }
    end)
  end

  def put_property(%Node{} = node, name, value) do
    property = Properties.get_or_create_property(name)

    Repo.insert(
      %NodeProperty{
        node_id: node.id,
        property_id: property.id,
        value: value
      },
      on_conflict: [set: [value: value]],
      conflict_target: [:node_id, :property_id]
    )
  end

  def get_property(%Node{} = node, name) do
    q =
      from np in NodeProperty,
        join: p in Property,
        on: p.id == np.property_id,
        where: p.name == ^name and np.node_id == ^node.id,
        select: np.value

    Repo.one(q)
  end

  def delete_property(%Node{} = node, name) do
    q =
      from np in NodeProperty,
        join: p in Property,
        on: p.id == np.property_id,
        where: np.node_id == ^node.id and p.name == ^name

    Repo.delete_all(q)
  end

  def put_properties(%Node{} = node, props) do
    Enum.reduce_while(props, :ok, fn e, _ ->
      case put_property(node, elem(e, 0), elem(e, 1)) do
        {:ok, _} -> {:cont, :ok}
        {:error, error} -> {:halt, {:error, error}}
      end
    end)
  end

  def get_properties(%Node{} = node) do
    q =
      from np in NodeProperty,
        join: p in Property,
        on: p.id == np.property_id,
        where: np.node_id == ^node.id,
        select: {p.name, np.value}

    q |> Repo.all() |> Enum.into(%{})
  end
end

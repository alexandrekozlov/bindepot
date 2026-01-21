defmodule Bindepot.Core.NodeProperties do
  import Ecto.Changeset

  alias Bindepot.Repo
  alias Bindepot.Core.Node
  alias Bindepot.Core.NodeProperty
  alias Bindepot.Core.Property

  def add_property(%Node{} = node, name, value) do
    property =
      Repo.get_by(Property, name: name) ||
        %Property{}
        |> Property.changeset(%{name: name})
        |> Repo.insert_or_update!()

    %NodeProperty{}
    |> NodeProperty.changeset(%{value: value})
    |> put_assoc(:node, node)
    |> put_assoc(:property, property)
    |> Repo.insert_or_update()
  end

  def add_properties(%Node{} = node, props) do
    Enum.reduce_while(props, :ok, fn e, _ ->
      case add_property(node, elem(e, 0), elem(e, 1)) do
        {:ok, _} -> {:cont, :ok}
        {:error, error} -> {:halt, {:error, error}}
      end
    end)
  end

  def get_properties(%Node{} = node) do
    node
    |> Repo.preload(node_properties: [:property])
    |> then(& &1.node_properties)
    |> Enum.reduce(%{}, fn e, a -> Map.put(a, e.property.name, e.value) end)
  end
end

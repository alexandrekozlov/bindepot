defmodule Bindepot.Core.Properties do
  alias Bindepot.Repo
  alias Bindepot.Core.Property

  def all() do
    Repo.all(Property)
  end

  def get_or_create_property(name) do
    Repo.get_by(Property, name: name) ||
      %Property{}
      |> Property.changeset(%{name: name})
      |> Repo.insert!()
  end

  def get_or_create_properties(names) do
    names
    |> Enum.uniq()
    |> Enum.map(fn n -> get_or_create_property(n) end)
  end
end

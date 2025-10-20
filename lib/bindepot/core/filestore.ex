defmodule Bindepot.Core.Filestore do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key false

  schema "filestores" do
    field :name, :string, primary_key: true
    field :provider, :string
    field :configuration, :map
  end

  def changeset(struct, params) do
    struct
    |> cast(params, [:name, :provider, :configuration])
    |> validate_required([:name, :provider])
    |> unique_constraint(:name)
  end
end

defmodule Bindepot.Core.Store do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "stores" do
    field :name, :string
    field :provider, :string
    field :configuration, :map
  end

  def changeset(struct, params) do
    struct
    |> cast(params, [:name, :provider, :configuration])
    |> validate_required([:name, :provider])
  end
end

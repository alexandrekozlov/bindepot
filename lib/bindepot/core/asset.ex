defmodule Bindepot.Core.Asset do
  import Ecto.Changeset
  use Ecto.Schema

  alias Bindepot.Core.{Repository, Store}

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "assets" do
    field :store_path, :string

    field :name, :string

    belongs_to :store, Store
    belongs_to :repository, Repository

    timestamps()
    field :accessed_at, :naive_datetime
  end

  def changeset(struct, params) do
    struct
    |> cast(params, [
      :id,
      :store_path,
      :name,
      :accessed_at
    ])
    |> validate_required([:name])
  end
end

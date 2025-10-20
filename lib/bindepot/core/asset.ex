defmodule Bindepot.Core.Asset do
  import Ecto.Changeset
  use Ecto.Schema

  alias Bindepot.Core.{Repository, Filestore}

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "assets" do
    field :store_path, :string

    field :name, :string

    belongs_to :filestore, Filestore, foreign_key: :filestore_name, references: :name, type: :string
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
      :filestore_name,
      :repository_id,
      :accessed_at
    ])
    |> assoc_constraint(:filestore)
    |> assoc_constraint(:repository)
    |> validate_required([:name])
  end
end

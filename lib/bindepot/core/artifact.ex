defmodule Bindepot.Core.Artifact do
  alias Bindepot.Core.Repository

  import Ecto.Changeset
  use Ecto.Schema

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "artifacts" do
    field :name, :string
    field :path, :string

    belongs_to :repository, Repository

    timestamps()
    field :accessed_at, :naive_datetime
  end

  def changeset(struct, params) do
    struct
    |> cast(params, [
      :id,
      :name,
      :path,
      :accessed_at
    ])
    |> validate_required([:name, :path])
    |> unique_constraint(:name)
  end
end

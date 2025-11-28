defmodule Bindepot.Core.Version do
  import Ecto.Changeset
  use Ecto.Schema

  alias Bindepot.Core.Package
  alias Bindepot.Core.DistFile

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "versions" do
    field :version, :string

    belongs_to :package, Package

    has_many :dist_files, DistFile
  end

  def changeset(struct, params) do
    struct
    |> cast(params, [
      :id,
      :version,
      :package_id
    ])
    |> cast_assoc(:package, required: false)
    |> validate_required([:version])
    |> assoc_constraint(:package)
    |> unique_constraint([:package_id, :version])
  end
end

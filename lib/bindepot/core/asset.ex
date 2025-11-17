defmodule Bindepot.Core.Asset do
  import Ecto.Changeset
  use Ecto.Schema

  alias Bindepot.Core.Repository
  alias Bindepot.Core.Version

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "assets" do
    # Asset's original file name
    field :name, :string

    # Logical path under which asset is stored in repository
    # it may not be the same as the path under which the asset is accessible
    # within context of specific repository protocol.
    field :path, :string

    field :size, :integer

    field :md5, :string
    field :sha1, :string
    field :sha256, :string

    belongs_to :repository, Repository

    many_to_many :versions, Version, join_through: "assets_versions"

    timestamps()
    field :accessed_at, :naive_datetime
  end

  def changeset(struct, params) do
    struct
    |> cast(params, [
      :id,
      :name,
      :path,
      :size,
      :md5,
      :sha1,
      :sha256,
      :repository_id,
      #      :version_id,
      :accessed_at
    ])
    |> assoc_constraint(:repository)
    # |> assoc_constraint(:versions)
    |> validate_required([:name, :path, :size])
  end
end

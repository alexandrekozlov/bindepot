defmodule Bindepot.Core.DistFile do
  import Ecto.Changeset
  use Ecto.Schema

  alias Bindepot.Core.Version
  alias Bindepot.Core.Node

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "dist_files" do
    field :name, :string
    field :mime_type, :string

    belongs_to :version, Version
    belongs_to :node, Node
  end

  def changeset(dist_file, attrs) do
    dist_file
    |> cast(attrs, [:name, :mime_type, :version_id, :node_id])
    |> cast_assoc(:version, required: false)
    |> cast_assoc(:node, required: false)
    |> validate_required([:name])
    |> assoc_constraint(:version)
    |> assoc_constraint(:node)
  end
end

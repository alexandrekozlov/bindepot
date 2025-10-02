defmodule Bindepot.Npm.Version do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  schema "npm_versions" do
    field :pkg_id, :binary_id
    field :version, :string
    field :tarball_path, :string
    field :metadata, :map, default: %{}
    timestamps()
  end

  def changeset(v, attrs) do
    v
    |> cast(attrs, [:pkg_id, :version, :tarball_path, :metadata])
    |> validate_required([:pkg_id, :version, :tarball_path])
    |> foreign_key_constraint(:pkg_id)
  end
end

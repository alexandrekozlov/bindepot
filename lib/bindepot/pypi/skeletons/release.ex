defmodule Bindepot.Pypi.Release do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "pypi_releases" do
    field :version, :string
    field :released_at, :naive_datetime_usec
    field :pkg_id, :binary_id
    field :metadata, :map, default: %{}
    timestamps()
  end

  def changeset(rel, attrs) do
    rel
    |> cast(attrs, [:version, :released_at, :pkg_id, :metadata])
    |> validate_required([:version, :pkg_id])
    |> foreign_key_constraint(:pkg_id)
    |> unique_constraint([:pkg_id, :version], name: :pypi_releases_pkg_id_version_index)
  end
end

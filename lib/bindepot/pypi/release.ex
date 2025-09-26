defmodule Bindepot.Pypi.Release do
  use Ecto.Schema
  import Ecto.Changeset

  schema "pypi_releases" do
    field :version, :string
    field :metadata, :map
    belongs_to :pypi_package, Bindepot.Pypi.Package
    has_many :pypi_dist_files, Bindepot.Pypi.DistFile, foreign_key: :pypi_release_id
    timestamps()
  end

  def changeset(release, attrs) do
    release
    |> cast(attrs, [:version, :metadata, :pypi_package_id])
    |> validate_required([:version, :pypi_package_id])
  end
end

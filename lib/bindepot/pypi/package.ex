defmodule Bindepot.Pypi.Package do
  use Ecto.Schema
  import Ecto.Changeset

  schema "pypi_packages" do
    field :name, :string
    belongs_to :repository, Bindepot.Core.Repository
    has_many :pypi_releases, Bindepot.Pypi.Release, foreign_key: :pypi_package_id
    timestamps()
  end

  def changeset(pkg, attrs) do
    pkg
    |> cast(attrs, [:name])
    |> validate_required([:name])
    |> unique_constraint(:name)
  end
end

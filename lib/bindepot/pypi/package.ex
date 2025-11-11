defmodule Bindepot.PyPI.Package do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "pypi_packages" do
    field :name, :string
    field :normalized_name, :string
    field :metadata, :map, default: %{}
    field :repo_id, :binary_id
    timestamps()
  end

  def changeset(pkg, attrs) do
    pkg
    |> cast(attrs, [:name, :normalized_name, :metadata, :repo_id])
    |> validate_required([:name, :normalized_name, :repo_id])
    |> unique_constraint([:repo_id, :normalized_name],
      name: :pypi_packages_repo_id_normalized_name_index
    )
    |> foreign_key_constraint(:repo_id)
  end
end

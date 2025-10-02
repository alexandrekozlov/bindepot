defmodule Bindepot.R.Package do
  use Ecto.Schema
  import Ecto.Changeset
  @primary_key {:id, :binary_id, autogenerate: true}

  schema "r_packages" do
    field :name, :string
    field :version, :string
    field :repo_id, :binary_id
    field :tarball_path, :string
    field :metadata, :map, default: %{}
    timestamps()
  end

  def changeset(p, attrs) do
    p
    |> cast(attrs, [:name, :version, :repo_id, :tarball_path, :metadata])
    |> validate_required([:name, :repo_id, :tarball_path])
    |> foreign_key_constraint(:repo_id)
  end
end

defmodule Bindepot.Rpm.Package do
  use Ecto.Schema
  import Ecto.Changeset
  @primary_key {:id, :binary_id, autogenerate: true}

  schema "rpm_packages" do
    field :name, :string
    field :version, :string
    field :release, :string
    field :architecture, :string
    field :repo_id, :binary_id
    field :file_path, :string
    timestamps()
  end

  def changeset(p, attrs) do
    p
    |> cast(attrs, [:name, :version, :release, :architecture, :repo_id, :file_path])
    |> validate_required([:name, :repo_id, :file_path])
    |> foreign_key_constraint(:repo_id)
  end
end

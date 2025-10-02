defmodule Bindepot.Npm.Package do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  schema "npm_packages" do
    field :name, :string
    field :scope, :string
    field :repo_id, :binary_id
    field :metadata, :map, default: %{}
    timestamps()
  end

  def changeset(s, attrs) do
    s
    |> cast(attrs, [:name, :scope, :repo_id, :metadata])
    |> validate_required([:name, :repo_id])
    |> foreign_key_constraint(:repo_id)
  end
end

defmodule Bindepot.Puppet.Module do
  use Ecto.Schema
  import Ecto.Changeset
  @primary_key {:id, :binary_id, autogenerate: true}

  schema "puppet_modules" do
    field :name, :string
    field :version, :string
    field :repo_id, :binary_id
    field :file_path, :string
    field :metadata, :map, default: %{}
    timestamps()
  end

  def changeset(m, attrs) do
    m
    |> cast(attrs, [:name, :version, :repo_id, :file_path, :metadata])
    |> validate_required([:name, :repo_id, :file_path])
    |> foreign_key_constraint(:repo_id)
  end
end

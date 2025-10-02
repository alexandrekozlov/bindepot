defmodule Bindepot.Generic.Repository do
  use Ecto.Schema
  import Ecto.Changeset
  @primary_key {:id, :binary_id, autogenerate: false}

  schema "generic_repositories" do
    field :repo_id, :binary_id
    field :meta, :map, default: %{}
    timestamps()
  end

  def changeset(gr, attrs) do
    gr
    |> cast(attrs, [:id, :repo_id, :meta])
    |> validate_required([:id, :repo_id])
    |> foreign_key_constraint(:repo_id)
  end
end

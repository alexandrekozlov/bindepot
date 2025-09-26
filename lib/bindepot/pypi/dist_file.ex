defmodule Bindepot.Pypi.DistFile do
  use Ecto.Schema
  import Ecto.Changeset

  schema "pypi_dist_files" do
    field :filename, :string
    field :url, :string
    field :path, :string
    field :hashes, :map
    belongs_to :pypi_release, Bindepot.Pypi.Release
    timestamps()
  end

  def changeset(df, attrs) do
    df
    |> cast(attrs, [:filename, :url, :path, :hashes, :release_id])
    |> validate_required([:filename, :release_id])
  end
end

defmodule Bindepot.Pypi.DistFile do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  schema "pypi_dist_files" do
    field :release_id, :binary_id
    field :filename, :string
    field :file_path, :string
    field :size, :integer
    field :sha256, :string
    field :content_type, :string
    timestamps()
  end

  def changeset(df, attrs) do
    df
    |> cast(attrs, [:release_id, :filename, :file_path, :size, :sha256, :content_type])
    |> validate_required([:release_id, :filename, :file_path, :size, :sha256])
    |> foreign_key_constraint(:release_id)
  end
end

defmodule Bindepot.Core.Node do
  @moduledoc """
    Represents a node in file hierachy.
  """

  import Ecto.Changeset
  use Ecto.Schema

  alias Bindepot.Core.Repository
  alias Bindepot.Core.DistFile
  alias Bindepot.Core.Blob

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "nodes" do
    field :type, :integer
    field :path, :string
    field :name, :string

    belongs_to :repository, Repository
    belongs_to :blob, Blob

    has_one :dist_file, DistFile
  end

  def changeset(struct, params) do
    struct
    |> cast(params, [
      :type,
      :path,
      :name,
      :repository_id,
      :blob_id
    ])
    |> assoc_constraint(:repository)
    |> validate_required([:type, :path, :name])
    |> validate_file_node()
  end

  @doc """
    Checks that file node (type: 1), has `blob_id` value.
  """
  defp validate_file_node(changeset) do
    if fetch_field!(changeset, :type) == 1 and
         is_nil(fetch_field!(changeset, :blob_id)) do
      add_error(changeset, :blob_id, "blob required for file node")
    else
      changeset
    end
  end
end

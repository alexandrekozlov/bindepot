defmodule Bindepot.Core.Blob do
  import Ecto.Changeset
  use Ecto.Schema

  alias Bindepot.Core.Node

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "blobs" do
    field :size, :integer
    field :md5, :string
    field :sha1, :string
    field :sha256, :string
    field :blaze2, :string

    has_many :nodes, Node
  end

  def changeset(struct, params) do
    struct
    |> cast(params, [
      :size,
      :md5,
      :sha1,
      :sha256,
      :blaze2
    ])
    |> validate_required([:size, :sha256])
  end
end

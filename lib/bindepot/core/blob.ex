defmodule Bindepot.Core.Blob do
  import Ecto.Changeset
  import Ecto.Query
  use Ecto.Schema

  alias Bindepot.Core.Blob
  alias Bindepot.Core.Node

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "blobs" do
    field :size, :integer
    field :md5, :string
    field :sha1, :string
    field :sha256, :string
    field :blake2, :string

    has_many :nodes, Node
  end

  def changeset(struct, params) do
    struct
    |> cast(params, [
      :size,
      :md5,
      :sha1,
      :sha256,
      :blake2
    ])
    |> validate_required([:size, :sha256])
    |> unique_constraint(:sha256)
    |> validate_immutable([:size, :md5, :sha1, :sha256, :blake2])
  end

  def base() do
    Blob
  end

  def all(query \\ base()) do
    query
  end

  def by_sha256(query \\ base(), sha256) do
    where(query, [b], b.sha256 == ^sha256)
  end

  defp validate_immutable(changeset, fields) do
    Enum.reduce(fields, changeset, fn e, a ->
      check_new_or_same(a, e)
    end)
  end

  defp check_new_or_same(changeset, field) do
    case {Map.get(changeset.data, field), get_change(changeset, field)} do
      {nil, nil} -> changeset
      {nil, _new} -> changeset
      {_current, nil} -> changeset
      {_current, _new} -> add_error(changeset, field, "new value does not match the existing one")
    end
  end
end

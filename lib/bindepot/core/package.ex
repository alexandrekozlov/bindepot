defmodule Bindepot.Core.Package do
  import Ecto.Changeset
  use Ecto.Schema

  alias Bindepot.Core.Version

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "packages" do
    field :name, :string
    field :type, :string

    has_many :versions, Version
  end

  @package_types ~w(generic)

  def changeset(struct, params) do
    struct
    |> cast(params, [
      :id,
      :name,
      :type
    ])
    |> validate_required([:name, :type])
    |> validate_format(:name, ~r/\S+/)
    |> validate_inclusion(:type, @package_types)
  end
end

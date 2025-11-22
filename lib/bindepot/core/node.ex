defmodule Bindepot.Core.Node do
  # import Ecto.Changeset
  use Ecto.Schema

  alias Bindepot.Core.Repository
  alias Bindepot.Core.DistFile

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "nodes" do
    field :type, :integer
    field :path, :string
    field :name, :string

    belongs_to :repository, Repository
    has_one :dist_file, DistFile
  end
end

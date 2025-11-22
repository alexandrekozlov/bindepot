defmodule Bindepot.Core.Repository do
  alias Ecto.Changeset
  alias Bindepot.Core.Repository
  alias Bindepot.Core.Asset
  alias Bindepot.Core.Node

  use Ecto.Schema
  import Ecto.Query
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "repositories" do
    field :name, :string
    field :type, :string
    field :package_type, :string
    field :url, :string
    field :repositories, {:array, :string}

    has_many :nodes, Node
    has_many :assets, Asset

    timestamps()
    field :deleted_at, :naive_datetime
  end

  @repository_types ~w(local remote virtual)

  def create_changeset(struct, params) do
    struct
    |> cast(params, [
      :id,
      :name,
      :type,
      :package_type,
      :url,
      :repositories
    ])
    |> validate_required([:name, :type, :package_type])
    |> validate_format(:name, ~r/\S+/)
    |> validate_inclusion(:type, @repository_types)
    |> validate_configuration()
    |> unique_constraint(:name)
  end

  def update_changeset(struct, params) do
    struct
    |> cast(params, [
      :name,
      :url,
      :repositories
    ])
    |> validate_required([:name])
    |> validate_configuration()
    |> unique_constraint(:name)
  end

  def change(repository, :new, params) do
    create_changeset(repository, params)
  end

  def change(repository, :edit, params) do
    update_changeset(repository, params)
  end

  def delete_changeset(struct, params) do
    struct
    |> cast(params, [:name, :deleted_at])
    |> validate_required([:deleted_at])
  end

  def repository_types() do
    Enum.to_list(@repository_types)
  end

  def is_repository_type(%Changeset{} = changeset, repository_type)
      when is_atom(repository_type) do
    case get_field(changeset, :type) do
      type when is_atom(type) ->
        type == repository_type

      type when is_binary(type) ->
        type == to_string(repository_type)

      _ ->
        false
    end
  end

  def remote?(repo) do
    repo |> change() |> is_repository_type(:remote)
  end

  def virtual?(repo) do
    repo |> change() |> is_repository_type(:virtual)
  end

  def base() do
    Repository
  end

  def all(query \\ base()) do
    query
  end

  def existing(query \\ base()) do
    where(query, [r], is_nil(r.deleted_at))
  end

  def deleted(query \\ base()) do
    where(query, [r], not is_nil(r.deleted_at))
  end

  def by_name(query \\ base(), name) do
    where(query, [r], r.name == ^name)
  end

  def by_repository_type(query \\ base(), repository_type) do
    where(query, [r], r.type == ^repository_type)
  end

  def by_package_type(query \\ base(), package_type) do
    where(query, [r], r.package_type == ^package_type)
  end

  defp validate_configuration(changeset) do
    cond do
      remote?(changeset) ->
        validate_required(changeset, :url)

      virtual?(changeset) ->
        validate_required(changeset, :repositories)

      true ->
        changeset
    end
  end
end

defmodule Bindepot.Core.Repository do
  alias Ecto.Changeset
  alias Bindepot.Core.Repository
  alias Bindepot.Core.Repositories
  use Ecto.Schema
  import Ecto.Query
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  schema "repositories" do
    field :name, :string
    field :repository_type, :string
    field :package_type, :string
    field :url, :string
    field :repositories, {:array, :string}

    timestamps()
    field :deleted_at, :naive_datetime
  end

  @repo_types ~w(local remote virtual)

  def changeset(struct, params) do
    struct
    |> cast(params, [
      :id,
      :name,
      :repository_type,
      :package_type,
      :url,
      :repositories,
      :deleted_at
    ])
    |> validate_required([:name, :repository_type, :package_type])
    |> validate_inclusion(:repository_type, @repo_types)
    |> validate_configuration()
    |> unique_constraint(:name)
  end

  def change(struct, :new, params) do
    struct
    |> cast(params, ~W(name repository_type package_type url repositories)a)
    |> validate_format(:name, ~r/\S+/)
    |> validate_inclusion(:repository_type, @repo_types)
  end

  def change(struct, :edit, params) do
    struct
    |> cast(params, ~W(name url repositories)a)
    |> validate_required([:name])
    |> validate_configuration()
  end

  def repository_types() do
    Enum.to_list(@repo_types)
  end

  def new(struct = %Repository{}, params) do
    struct
    |> cast(params, [:name, :repository_type, :package_type, :url, :repositories])
  end

  def change(struct = %Repository{}, params) do
    struct
    |> cast(params, [:name, :url, :repositories])
    |> unique_constraint(:name)
    |> validate_configuration()
  end

  def delete(struct = %Repository{}, params) do
    struct
    |> cast(params, [:id])
    |> validate_required([:id])
  end

  def is_repository_type(%Changeset{} = changeset, repository_type)
      when is_atom(repository_type) do
    case get_field(changeset, :repository_type) do
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

  def deleted() do
    from(p in Repository, where: not is_nil(p.deleted_at))
  end

  defp validate_configuration(changeset) do
    cond do
      remote?(changeset) -> validate_required(changeset, :url)
      virtual?(changeset) -> validate_required(changeset, :repositories)
      true ->
        changeset
    end
  end

end

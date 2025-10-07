defmodule Bindepot.Core.Repository do
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
    field :configuration, :map, default: %{}

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
      :configuration,
      :deleted_at
    ])
    |> validate_required([:name, :repository_type, :package_type])
    |> validate_inclusion(:repository_type, @repo_types)
    |> validate_configuration()
    |> unique_constraint(:name)
  end

  def repository_types() do
    Enum.to_list(@repo_types)
  end

  def change(struct = %Repository{}, params) do
    struct
    |> cast(params, [:name, :configuration])
    |> unique_constraint(:name)
    |> validate_configuration()
  end

  def delete(struct = %Repository{}, params) do
    struct
    |> cast(params, [:id])
    |> validate_required([:id])
  end

  def deleted() do
    from(p in Repository, where: not is_nil(p.deleted_at))
  end

  defp validate_configuration(changeset) do
    case get_field(changeset, :repository_type) do
      "remote" -> validate_remote_repository_configuration(changeset)
      "virtual" -> validate_virtual_repository_configuration(changeset)
      _ -> changeset
    end
  end

  defp validate_remote_repository_configuration(changeset) do
    config = get_field(changeset, :configuration) || %{}

    case Map.get(config, "url") do
      url when is_binary(url) -> changeset
      _ -> add_error(changeset, :configuration, "'url' is not a string")
      nil -> add_error(changeset, :configuration, "missing `url` key")
    end
  end

  defp validate_virtual_repository_configuration(changeset) do
    config = get_field(changeset, :configuration) || %{}

    case Map.get(config, "repositories") do
      repo_list when is_list(repo_list) -> changeset
      _ -> add_error(changeset, :configuration, "`repositories` is not a list")
      nil -> add_error(changeset, :configuration, "missing `repositories` key")
    end
  end
end

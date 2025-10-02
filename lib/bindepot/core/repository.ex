defmodule Bindepot.Core.Repository do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  schema "repositories" do
    field :name, :string
    field :repository_type, :string
    field :package_type, :string
    field :configuration, :map, default: %{}
    field :properties, :map, default: %{}
    field :deleted_at, :naive_datetime_usec
    timestamps()
  end

  @repo_types ~w(local remote virtual)
  def changeset(repo, attrs) do
    repo
    |> cast(attrs, [:id, :name, :repository_type, :package_type, :configuration, :properties, :deleted_at])
    |> validate_required([:name, :repository_type, :package_type])
    |> validate_inclusion(:repository_type, @repo_types)
    |> validate_configuration()
    |> unique_constraint(:name)
  end

  defp validate_configuration(changeset) do
    case get_field(changeset, :repository_type) do
      "remote" -> validate_required_in_map(changeset, ["url"])
      "virtual" -> validate_required_in_map(changeset, ["repositories"])
      _ -> changeset
    end
  end

  defp validate_required_in_map(changeset, keys) do
    cfg = get_field(changeset, :configuration) || %{}
    missing = Enum.filter(keys, &(!Map.has_key?(cfg, &1)))
    if missing == [], do: changeset, else: add_error(changeset, :configuration, "missing keys: #{Enum.join(missing, ", ")}")
  end
end

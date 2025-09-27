defmodule Bindepot.Core.Repository do
  use Ecto.Schema
  import Ecto.Changeset

  alias Bindepot.Repo
  alias Bindepot.Core.Repository

  schema "repositories" do
    field :name, :string
    field :repository_type, :string
    field :package_type, :string
    field :properties, :map
    timestamps()
  end

  def changeset(pkg, attrs) do
    pkg
    |> cast(attrs, [:name])
    |> validate_required([:name, :repository_type, :package_type])
    |> unique_constraint(:name)
  end

  def create_repository(_name, repository_type, _package_type, _properties) do
    case repository_type do
      :local -> :ok
      :remote -> :ok
      :virtual -> :ok
    end
  end

  defp create_remote_repository(name, package_type, properties) do
    url = Map.fetch!(properties, "url")

    Repo.transact(fn ->
      { :ok, %{ id: id } } = %Repository{}
        |> Repository.changeset(%{name: name, repository_type: :local, package_type: package_type, properties: properties})
        |> Repo.insert!()

      # handle uploaded file if present
      File.mkdir_p!(Path.join("cache", id))
      {:ok, id}
    end)
  end

end

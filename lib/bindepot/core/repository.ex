defmodule Bindepot.Core.Repository do
  use Ecto.Schema
  import Ecto.Changeset

  alias Ecto.UUID
  alias Bindepot.Repo
  alias Bindepot.Core.Repository

  schema "repositories" do
    field :name, :string
    field :repository_type, Ecto.Enum, values: [:local, :remote, :virtual]
    field :package_type, :string
    field :configuration, :map
    field :properties, :map
    timestamps()
  end

  def changeset(pkg, attrs) do
    pkg
    |> cast(attrs, [:name, :repository_type, :package_type])
    |> validate_required([:name, :repository_type, :package_type])
    |> unique_constraint(:name)
  end

  def create_repository(name, repository_type, package_type, configuration, properties) do
    with {:ok, _} <- check_configuration(repository_type, configuration) do
      Repo.transact(fn ->
        do_create_repo!(name, repository_type, package_type, configuration, properties)
      end)
    end
  end

  def delete_repository(name) do
    {:ok, id} = Repo.get_by!(Repository, name: name)
    %Repository{id: id} |> Repo.delete()
  end

  defp check_configuration(:local, _configuration) do
    {:ok, nil}
  end

  defp check_configuration(:remote, configuration) do
    case Map.fetch(configuration, "url") do
      {:ok, url} when is_binary(url) -> { :ok, nil }
      {:ok, _} -> { :error, "'url' parameter must be string"}
      {:error, _} -> {:error, "remote repository requires 'url' configuration parameter"}
    end
  end

  defp check_configuration(:virtual, configuration) do
    case Map.fetch(configuration, "repositories)") do
      {:ok, repositories} when is_list(repositories) -> { :ok, nil }
      {:ok, _} -> { :error, "'repositories' parameter must be list"}
      {:error, _} -> {:error, "virtual repository requires 'repositories' configuration parameter"}
    end
  end

  defp do_create_repo!(name, repository_type, package_type, configuration, properties) do
    params = %{
      name: name,
      repository_type: repository_type,
      package_type: package_type,
      configuration: configuration,
      properties: properties
    }

    repo =
      %Repository{}
      |> Repository.changeset(params)
      |> Repo.insert!()

    Path.join(Application.fetch_env!(:bindepot, :data_dir), to_string(repo.id))
      |> File.mkdir_p!()
    {:ok, repo.id}
  end
end

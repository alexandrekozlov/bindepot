defmodule Bindepot.Repo.Migrations.CreatePackagesAndReleases do
  use Ecto.Migration

  def change do
    create table(:repositories) do
      add :name, :string, null: false
      add :repository_type, :string
      add :package_type, :string
      timestamps()
    end

    create table(:pypi_packages) do
      add :name, :string, null: false
      add :repository_id, references(:repositories, on_delete: :delete_all), null: false
      timestamps()
    end

    create unique_index(:pypi_packages, [:repository_id])

    create table(:pypi_releases) do
      add :pypi_package_id, references(:pypi_packages, on_delete: :delete_all), null: false
      add :version, :string, null: false
      add :metadata, :map
      timestamps()
    end

    create index(:pypi_releases, [:pypi_package_id])

    create table(:pypi_dist_files) do
      add :pypi_release_id, references(:pypi_releases, on_delete: :delete_all), null: false
      add :filename, :string, null: false
      add :url, :string
      add :path, :string
      add :hashes, :map
      timestamps()
    end

    create index(:pypi_dist_files, [:pypi_release_id])
  end
end

defmodule Bindepot.Repo.Migrations.CreateRepositories do
  use Ecto.Migration

  def change do
    create table(:repositories, primary_key: false) do
      add :id, :uuid, primary_key: true, null: false
      add :name, :string, null: false
      add :repository_type, :string, null: false
      add :package_type, :string, null: false
      add :url, :string, null: true
      add :repositories, {:array, :string}, default: [], null: false

      add :inserted_at, :naive_datetime_usec, null: false
      add :updated_at, :naive_datetime_usec, null: false
      add :deleted_at, :naive_datetime_usec
    end

    create unique_index(:repositories, [:name])
    create index(:repositories, [:repository_type])
    create index(:repositories, [:package_type])
    create index(:repositories, [:deleted_at])

    create table(:artifacts, primary_key: false) do
      add :id, :uuid, primary_key: true, null: false
      add :name, :string, null: false
      add :path, :string, null: false

      add :repository_id,
          :uuid,
          [references(:repositories, type: :uuid, on_delete: :delete_all, on_update: :update_all)]

      add :inserted_at, :naive_datetime_usec, null: false
      add :updated_at, :naive_datetime_usec, null: false
      add :accessed_at, :naive_datetime_usec
    end

    create unique_index(:artifacts, :name)

    # PyPI
    create table(:pypi_packages, primary_key: false) do
      add :id, :uuid, primary_key: true, null: false
      add :repo_id, :uuid, null: false
      add :name, :string, null: false
      add :normalized_name, :string, null: false
      add :metadata, :map, default: %{}, null: false
      timestamps()
    end

    create index(:pypi_packages, [:repo_id])

    create unique_index(:pypi_packages, [:repo_id, :normalized_name],
             name: :pypi_packages_repo_id_normalized_name_index
           )

    create table(:pypi_releases, primary_key: false) do
      add :id, :uuid, primary_key: true, null: false
      add :pkg_id, :uuid, null: false
      add :version, :string, null: false
      add :released_at, :naive_datetime_usec
      add :metadata, :map, default: %{}, null: false
      timestamps()
    end

    create index(:pypi_releases, [:pkg_id])

    create unique_index(:pypi_releases, [:pkg_id, :version],
             name: :pypi_releases_pkg_id_version_index
           )

    create table(:pypi_dist_files, primary_key: false) do
      add :id, :uuid, primary_key: true, null: false
      add :release_id, :uuid, null: false
      add :filename, :string, null: false
      add :file_path, :string, null: false
      add :size, :bigint, null: false
      add :sha256, :string, null: false
      add :content_type, :string
      timestamps()
    end

    create index(:pypi_dist_files, [:release_id])

    # NPM
    create table(:npm_packages, primary_key: false) do
      add :id, :uuid, primary_key: true, null: false
      add :repo_id, :uuid, null: false
      add :name, :string, null: false
      add :scope, :string
      add :metadata, :map, default: %{}, null: false
      timestamps()
    end

    create index(:npm_packages, [:repo_id])

    create table(:npm_versions, primary_key: false) do
      add :id, :uuid, primary_key: true, null: false
      add :pkg_id, :uuid, null: false
      add :version, :string, null: false
      add :tarball_path, :string, null: false
      add :metadata, :map, default: %{}, null: false
      timestamps()
    end

    create index(:npm_versions, [:pkg_id])

    # RPM
    create table(:rpm_packages, primary_key: false) do
      add :id, :uuid, primary_key: true, null: false
      add :repo_id, :uuid, null: false
      add :name, :string, null: false
      add :version, :string
      add :release, :string
      add :architecture, :string
      add :file_path, :string, null: false
      timestamps()
    end

    create index(:rpm_packages, [:repo_id])

    # Puppet
    create table(:puppet_modules, primary_key: false) do
      add :id, :uuid, primary_key: true, null: false
      add :repo_id, :uuid, null: false
      add :name, :string, null: false
      add :version, :string
      add :file_path, :string
      add :metadata, :map, default: %{}, null: false
      timestamps()
    end

    create index(:puppet_modules, [:repo_id])

    # R
    create table(:r_packages, primary_key: false) do
      add :id, :uuid, primary_key: true, null: false
      add :repo_id, :uuid, null: false
      add :name, :string, null: false
      add :version, :string
      add :tarball_path, :string
      add :metadata, :map, default: %{}, null: false
      timestamps()
    end

    create index(:r_packages, [:repo_id])

    # Foreign key constraints referencing repositories.id
    alter table(:pypi_packages) do
      modify :repo_id, references(:repositories, column: :id, type: :uuid, on_delete: :delete_all)
    end

    alter table(:pypi_releases) do
      modify :pkg_id, references(:pypi_packages, column: :id, type: :uuid, on_delete: :delete_all)
    end

    alter table(:pypi_dist_files) do
      modify :release_id,
             references(:pypi_releases, column: :id, type: :uuid, on_delete: :delete_all)
    end

    alter table(:npm_packages) do
      modify :repo_id, references(:repositories, column: :id, type: :uuid, on_delete: :delete_all)
    end

    alter table(:npm_versions) do
      modify :pkg_id, references(:npm_packages, column: :id, type: :uuid, on_delete: :delete_all)
    end

    alter table(:rpm_packages) do
      modify :repo_id, references(:repositories, column: :id, type: :uuid, on_delete: :delete_all)
    end

    alter table(:puppet_modules) do
      modify :repo_id, references(:repositories, column: :id, type: :uuid, on_delete: :delete_all)
    end

    alter table(:r_packages) do
      modify :repo_id, references(:repositories, column: :id, type: :uuid, on_delete: :delete_all)
    end
  end
end

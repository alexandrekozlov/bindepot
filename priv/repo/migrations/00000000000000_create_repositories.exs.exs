defmodule Bindepot.Repo.Migrations.CreateRepositories do
  use Ecto.Migration

  def change do
    create table(:repositories, primary_key: false) do
      add :id, :uuid, primary_key: true, null: false
      add :name, :string, null: false
      add :type, :string, null: false
      add :package_type, :string, null: false
      add :url, :string, null: true
      add :repositories, {:array, :string}, default: [], null: false

      timestamps()
      add :deleted_at, :naive_datetime_usec
    end

    create unique_index(:repositories, [:name])
    create index(:repositories, [:type])
    create index(:repositories, [:deleted_at])

    create table(:filestores, primary_key: false) do
      add :name, :string, primary_key: true, null: false
      add :provider, :string, null: false
      add :configuration, :map, default: %{}, null: false
    end

    create table(:assets, primary_key: false) do
      add :id, :uuid, primary_key: true, null: false
      add :name, :string, null: false
      add :path, :string, null: false
      add :size, :integer, null: false

      add :md5, :string, null: true
      add :sha1, :string, null: true
      add :sha256, :string, null: true

      add :repository_id,
          references(:repositories,
            column: :id,
            type: :uuid,
            on_delete: :delete_all,
            on_update: :update_all
          )

      timestamps()
      add :accessed_at, :naive_datetime_usec
    end

    create unique_index(:assets, :name)

    create table("packages", primary_key: false) do
      add :id, :uuid, primary_key: true, null: false
      add :name, :string, null: false
      add :type, :string, null: false
    end

    create table("versions", primary_key: false) do
      add :id, :uuid, primary_key: true, null: false
      add :version, :string, null: false
    end

    create table("assets_versions", primary_key: false) do
      add :asset_id,
          references(:assets,
            column: :id,
            type: :uuid,
            on_delete: :delete_all
          ),
          null: false

      add :version_id,
          references(:versions,
            column: :id,
            type: :uuid,
            on_delete: :delete_all
          ),
          null: false

      timestamps()
    end

    create unique_index(:assets_versions, [:asset_id, :version_id])
  end
end

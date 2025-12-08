defmodule Bindepot.Repo.Migrations.CreateRepositories do
  use Ecto.Migration

  def change do
    create table("blobs", primary_key: false) do
      add :id, :uuid, primary_key: true, null: false
      add :size, :integer, null: false
      add :md5, :string
      add :sha1, :string
      add :sha256, :string, null: false
      add :blake2, :string
    end

    create unique_index("blobs", [:sha256], nulls_distinct: true)

    create table("repositories", primary_key: false) do
      add :id, :uuid, primary_key: true, null: false
      add :name, :string, null: false
      add :type, :string, null: false
      add :package_type, :string, null: false
      add :url, :string, null: true
      add :repositories, {:array, :string}, default: [], null: false

      timestamps()
      add :deleted_at, :naive_datetime_usec
    end

    create unique_index("repositories", [:name])
    create index("repositories", [:type])
    create index("repositories", [:deleted_at])

    create table("nodes", primary_key: false) do
      add :id, :uuid, primary_key: true, null: false
      add :type, :integer, null: false
      add :path, :string, null: false
      add :name, :string, null: false
      add :properties, :string, null: true

      add :repository_id,
          references("repositories",
            column: :id,
            type: :uuid,
            on_delete: :delete_all,
            on_update: :update_all
          )

      add :blob_id,
          references("blobs",
            column: :id,
            type: :uuid,
            on_delete: :delete_all,
            on_update: :update_all
          ),
          null: true
    end

    create unique_index("nodes", [:repository_id, :type, :path, :name])

    create table("packages", primary_key: false) do
      add :id, :uuid, primary_key: true, null: false
      add :name, :string, null: false
      add :type, :string, null: false
    end

    create unique_index("packages", [:name, :type])

    create table("versions", primary_key: false) do
      add :id, :uuid, primary_key: true, null: false
      add :version, :string, null: false

      add :package_id,
          references("packages",
            column: :id,
            type: :uuid,
            on_delete: :delete_all,
            on_update: :update_all
          ),
          null: false
    end

    create unique_index("versions", [:package_id, :version])

    create table("dist_files", primary_key: false) do
      add :id, :uuid, primary_key: true, null: false
      add :name, :string, null: false
      add :mime_type, :string, null: true

      add :version_id,
          references("versions",
            column: :id,
            type: :uuid,
            on_delete: :delete_all,
            on_update: :update_all
          ),
          null: false

      add :node_id,
          references("nodes",
            column: :id,
            type: :uuid,
            on_delete: :delete_all,
            on_update: :update_all
          ),
          null: false
    end

    unique_index("dist_files", [:name, :version_id, :node_id])

    create table("filestores", primary_key: false) do
      add :name, :string, primary_key: true, null: false
      add :provider, :string, null: false
      add :configuration, :map, default: %{}, null: false
    end
  end
end

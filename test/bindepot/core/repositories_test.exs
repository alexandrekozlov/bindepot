defmodule Bindepot.Core.RepositoryTest do
  use Bindepot.DataCase

  alias Bindepot.Core.Repositories
  alias Bindepot.Core.Assets

  describe "all/1" do
    setup do
      repository = %{
        name: "generic",
        repository_type: "local",
        package_type: "generic"
      }

      %{repository: repository}
    end

    test "list repos when there are none" do
      assert Repositories.all() == []
    end

    test "list active repos", %{repository: repository} do
      Repositories.create(repository)
      assert [%{name: "generic"}] = Repositories.all()
    end

    test "do not list deleted repos", %{repository: repository} do
      Repositories.create(repository)
      assert [%{name: "generic"} = repo] = Repositories.all()
      Repositories.delete(repo)
      assert Repositories.all() == []
    end

    test "list deleted repos", %{repository: repository} do
      Repositories.create(repository)
      [repo] = Repositories.all()
      Repositories.delete(repo)
      assert [%{name: "generic"}] = Repositories.all(include_deleted: true)
    end
  end

  describe "create/1" do
    test "create local repository" do
      now = NaiveDateTime.utc_now()

      assert {:ok, repository} =
               Repositories.create(%{
                 name: "generic",
                 repository_type: "local",
                 package_type: "generic"
               })

      assert %{name: "generic", repository_type: "local", package_type: "generic"} = repository

      assert repository.id != nil
      assert repository.url == nil
      assert repository.repositories == nil

      assert_within_seconds(repository.inserted_at, now)
      assert_within_seconds(repository.updated_at, now)
      assert repository.deleted_at == nil
    end

    test "create remote repository" do
      now = NaiveDateTime.utc_now()

      assert {:ok, repository} =
               Repositories.create(%{
                 name: "generic",
                 repository_type: "remote",
                 package_type: "generic",
                 url: "http://ftp.zymeworks.com"
               })

      assert %{
               name: "generic",
               repository_type: "remote",
               package_type: "generic",
               url: "http://ftp.zymeworks.com"
             } =
               repository

      assert repository.id != nil
      assert repository.repositories == nil

      assert_within_seconds(repository.inserted_at, now)
      assert_within_seconds(repository.updated_at, now)
      assert repository.deleted_at == nil
    end
  end

  describe "put and get asset" do
    setup do
      params = %{
        name: "generic",
        repository_type: "local",
        package_type: "generic"
      }

      {:ok, repository} = Repositories.create(params)
      %{repository: repository}
    end

    test "put and get", %{repository: repository} do
      assert {:ok, asset} =
               Assets.put(
                 repository,
                 "asset.bin",
                 Path.expand("./test/data/artifact.txt")
               )

      assert asset.id != nil
      assert asset.name == "asset.bin"
      assert asset.blob_ref != nil
      assert asset.filestore != nil

      assert {:ok, result} = Assets.get(asset)
      assert File.exists?(result)
    end

    test "put multiple assets", %{repository: repository} do
      assert {:ok, _asset} =
               Assets.put(
                 repository,
                 "asset.bin",
                 Path.expand("./test/data/artifact.txt")
               )

      assert {:ok, _asset} =
               Assets.put(
                 repository,
                 "/other/asset.bin",
                 Path.expand("./test/data/artifact.txt")
               )
    end

    test "replace asset", %{repository: repository} do
      assert {:ok, _asset} =
               Assets.put(
                 repository,
                 "asset.bin",
                 Path.expand("./test/data/artifact.txt")
               )

      assert {:ok, _asset} =
               Assets.put(
                 repository,
                 "asset.bin",
                 Path.expand("./test/data/artifact.txt")
               )
    end
  end
end

defmodule Bindepot.Core.RepositoryTest do
  use Bindepot.DataCase

  alias Bindepot.Core.Repositories
  alias Bindepot.Core.Assets

  describe "all/1" do
    setup do
      repository = %{
        name: "generic",
        type: "local",
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
      Repositories.delete(repo.id)
      assert Repositories.all() == []
    end

    test "list deleted repos", %{repository: repository} do
      Repositories.create(repository)
      [repo] = Repositories.all()
      Repositories.delete(repo.id)
      [%{name: name}] = Repositories.all_deleted()
      assert name =~ ~r/generic\$.+/
    end
  end

  describe "create/1" do
    test "create local repository" do
      now = NaiveDateTime.utc_now()

      assert {:ok, repository} =
               Repositories.create(%{
                 name: "generic",
                 type: "local",
                 package_type: "generic"
               })

      assert %{name: "generic", type: "local", package_type: "generic"} = repository

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
                 type: "remote",
                 package_type: "generic",
                 url: "http://ftp.zymeworks.com"
               })

      assert %{
               name: "generic",
               type: "remote",
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
      {:ok, repository} =
        Repositories.create(%{
          name: "generic",
          type: "local",
          package_type: "generic"
        })

      asset1_path =
        Temp.mkdir!()
        |> Path.join("asset1.bin")
        |> tap(&File.write(&1, "This is a small artifact"))

      asset2_path =
        Temp.mkdir!()
        |> Path.join("asset2.bin")
        |> tap(&File.write(&1, "This is a sligntly larger artifact"))

      %{repository: repository, asset1: asset1_path, asset2: asset2_path}
    end

    test "attempt to get invalid path should fail", ctx do
      refute Assets.get_stream(ctx.repository.id, "/")
    end

    test "attempt to get non-existing asset should fail", ctx do
      refute Assets.get_stream(ctx.repository.id, "/missing-asset.bin")
    end

    test "attempt to get non-file should fail", ctx do
      assert {:ok, _node} =
               Assets.put_file(
                 ctx.repository.id,
                 "/dir1/dir2/asset.bin",
                 Path.expand(ctx.asset1)
               )

      refute Assets.get_stream(ctx.repository.id, "/dir1/dir2")
    end

    test "after putting asset should be able to retrieve it", ctx do
      assert {:ok, node} =
               Assets.put_file(
                 ctx.repository.id,
                 "/asset.bin",
                 Path.expand(ctx.asset1)
               )

      assert node.path == "/"
      assert node.name == "asset.bin"

      assert Assets.get_stream(ctx.repository.id, "/asset.bin")
    end

    test "put multiple different assets", ctx do
      assert {:ok, _node} =
               Assets.put_file(
                 ctx.repository.id,
                 "/asset.bin",
                 Path.expand(ctx.asset1)
               )

      assert {:ok, _node} =
               Assets.put_file(
                 ctx.repository.id,
                 "/other/asset.bin",
                 Path.expand(ctx.asset2)
               )
    end

    test "replacing existing asset should fail", ctx do
      assert {:ok, _node} =
               Assets.put_file(
                 ctx.repository.id,
                 "/asset.bin",
                 Path.expand(ctx.asset1)
               )

      assert {:error, _node} =
               Assets.put_file(
                 ctx.repository.id,
                 "/asset.bin",
                 Path.expand(ctx.asset2)
               )
    end

    test "forcing asset replace should succeed", ctx do
      assert {:ok, _node} =
               Assets.put_file(
                 ctx.repository.id,
                 "/asset.bin",
                 Path.expand(ctx.asset1)
               )

      assert {:ok, _node} =
               Assets.put_file(
                 ctx.repository.id,
                 "/asset.bin",
                 Path.expand(ctx.asset2),
                 replace: true
               )
    end
  end
end

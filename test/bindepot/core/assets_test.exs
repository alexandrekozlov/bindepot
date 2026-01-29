defmodule Bindepot.Core.AssetsTest do
  use Bindepot.DataCase

  alias Bindepot.Core.Repositories
  alias Bindepot.Core.Assets

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

      assert {:error, _reason} =
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

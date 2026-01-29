defmodule Bindepot.Core.NodesTest do
  alias Bindepot.Core.NodeProperties
  use Bindepot.DataCase

  alias Bindepot.Core.Nodes

  describe "parse_path" do
    test "empty path resolves to a root path only" do
      assert {"/", nil} = Nodes.parse_path("")
    end

    test "root path resolves to a root path only" do
      assert {"/", nil} = Nodes.parse_path("/")
    end

    test "name at root resolves to a root path and a name" do
      assert {"/", "item"} = Nodes.parse_path("/item")
    end

    test "hierarchical path resolves to a prefix path and a name" do
      assert {"/dir1/dir2/dir3", "file"} = Nodes.parse_path("/dir1/dir2/dir3/file")
    end
  end

  describe "items_from_path" do
    test "empty path should return no nodes" do
      assert [] = Nodes.items_from_path("")
    end

    test "root path should return no nodes" do
      assert [] = Nodes.items_from_path("/")
    end

    test "single root element returns one node" do
      assert [{"/", "A"}] = Nodes.items_from_path("/A")
    end

    test "two elements return two nodes in reverse order" do
      assert [{"/A", "B"}, {"/", "A"}] = Nodes.items_from_path("/A/B")
    end

    test "three elements return three nodes in reverse order" do
      assert [{"/A/B", "C"}, {"/A", "B"}, {"/", "A"}] = Nodes.items_from_path("/A/B/C")
    end

    test "relative paths treated as absolute path" do
      assert [{"/A/B", "C"}, {"/A", "B"}, {"/", "A"}] = Nodes.items_from_path("A/B/C")
    end

    test "empty elements ignored" do
      assert [{"/A/B", "C"}, {"/A", "B"}, {"/", "A"}] = Nodes.items_from_path("/A//B/C")
    end

    test "trailing separator ignored" do
      assert [{"/A/B", "C"}, {"/A", "B"}, {"/", "A"}] = Nodes.items_from_path("/A/B/C/")
    end
  end

  def create_repositories(_ctx) do
    {:ok, repo1} =
      Bindepot.Core.Repositories.create(%{
        name: "generic-local-1",
        type: "local",
        package_type: "generic"
      })

    {:ok, repo2} =
      Bindepot.Core.Repositories.create(%{
        name: "generic-local-2",
        type: "local",
        package_type: "generic"
      })

    %{
      repo1: repo1,
      repo2: repo2
    }
  end

  def create_blobs(_ctx) do
    {:ok, blob1, _} =
      Bindepot.Core.Blobs.put(%{
        size: 1024,
        sha256: "sha-256-hash-1"
      })

    {:ok, blob2, _} =
      Bindepot.Core.Blobs.put(%{
        size: 1024,
        sha256: "sha-256-hash-2"
      })

    %{blob1: blob1, blob2: blob2}
  end

  describe "all" do
    setup [:create_repositories, :create_blobs]

    test "returns nothing in empty repo", ctx do
      assert [] == Nodes.all(ctx.repo1.id, "/")
    end

    test "returns nothing when empty", ctx do
      Nodes.create_file(ctx.repo1.id, "/A", ctx.blob1.id)

      assert [] == Nodes.all(ctx.repo1.id, "/A")
    end

    test "returns directories", ctx do
      Nodes.create_directory(ctx.repo1.id, "/A")
      Nodes.create_directory(ctx.repo1.id, "/B")

      assert ["A", "B"] ==
               Nodes.all(ctx.repo1.id, "/")
               |> Enum.map(fn e -> e.name end)
               |> Enum.sort(fn a, b -> a < b end)
    end

    test "returns files", ctx do
      Nodes.create_file(ctx.repo1.id, "/A", ctx.blob1.id)
      Nodes.create_file(ctx.repo1.id, "/B", ctx.blob2.id)

      assert ["A", "B"] ==
               Nodes.all(ctx.repo1.id, "/")
               |> Enum.map(fn e -> e.name end)
               |> Enum.sort(fn a, b -> a < b end)
    end

    test "returns mix of files and directories", ctx do
      Nodes.create_directory(ctx.repo1.id, "/A")
      Nodes.create_file(ctx.repo1.id, "/B", ctx.blob2.id)

      assert ["A", "B"] ==
               Nodes.all(ctx.repo1.id, "/")
               |> Enum.map(fn e -> e.name end)
               |> Enum.sort(fn a, b -> a < b end)
    end

    test "returns children only", ctx do
      Nodes.create_directory(ctx.repo1.id, "/A/B")
      Nodes.create_directory(ctx.repo1.id, "/A/C")
      Nodes.create_directory(ctx.repo1.id, "/A/D")

      assert ["B", "C", "D"] ==
               Nodes.all(ctx.repo1.id, "/A")
               |> Enum.map(fn e -> e.name end)
               |> Enum.sort(fn a, b -> a < b end)
    end

    test "returns immediate children only", ctx do
      Nodes.create_directory(ctx.repo1.id, "/A/B")
      Nodes.create_directory(ctx.repo1.id, "/A/B/C")
      Nodes.create_directory(ctx.repo1.id, "/A/B/C/D")

      assert ["B"] ==
               Nodes.all(ctx.repo1.id, "/A")
               |> Enum.map(fn e -> e.name end)
               |> Enum.sort(fn a, b -> a < b end)
    end

    test "returns all descendats when requested", ctx do
      Nodes.create_directory(ctx.repo1.id, "/A/B")
      Nodes.create_directory(ctx.repo1.id, "/A/B/C")
      Nodes.create_directory(ctx.repo1.id, "/A/B/C/D")
      Nodes.create_directory(ctx.repo1.id, "/A/B/C/E")

      assert ["/A/B", "/A/B/C", "/A/B/C/D", "/A/B/C/E"] ==
               Nodes.all(ctx.repo1.id, "/A", recursive: true)
               |> Enum.map(fn e -> e.path <> "/" <> e.name end)
               |> Enum.sort(fn a, b -> a < b end)
    end
  end

  describe "empty?" do
    setup [:create_repositories, :create_blobs]

    test "true when repo is empty", ctx do
      assert Nodes.empty?(ctx.repo1.id, "/")
    end

    test "true when directory is empty", ctx do
      Nodes.create_directory(ctx.repo1.id, "/A")

      refute Nodes.empty?(ctx.repo1.id, "/")
      assert Nodes.empty?(ctx.repo1.id, "/A")
    end

    test "false when directory has files", ctx do
      Nodes.create_directory(ctx.repo1.id, "/A")
      Nodes.create_file(ctx.repo1.id, "/A/B", ctx.blob1.id)

      refute Nodes.empty?(ctx.repo1.id, "/A")
    end
  end

  describe "create_directory" do
    setup [:create_repositories]

    test "creating a non-directory should fail", ctx do
      result =
        Nodes.create_directory(
          ctx.repo1.id,
          "/"
        )

      assert {:error, _reason, _node} = result
    end

    test "creating subdirectories one by one should succeed in all cases", ctx do
      assert {:ok, _} =
               Nodes.create_directory(
                 ctx.repo1.id,
                 "/A"
               )

      assert {:ok, _} =
               Nodes.create_directory(
                 ctx.repo1.id,
                 "/A/B"
               )

      assert {:ok, _} =
               Nodes.create_directory(
                 ctx.repo1.id,
                 "/A/B/C"
               )

      assert {:ok, _} =
               Nodes.create_directory(
                 ctx.repo1.id,
                 "/A/B/D"
               )
    end

    @tag skip: "Currently it is insert or update operation for directories"
    test "replacing an existing directory should fail", ctx do
      assert {:ok, _} =
               Nodes.create_directory(
                 ctx.repo1.id,
                 "/A"
               )

      assert {:error, _} =
               Nodes.create_directory(
                 ctx.repo1.id,
                 "/A"
               )
    end
  end

  describe "create_file" do
    setup [:create_repositories, :create_blobs]

    test "creating a file with an empty path should fail", ctx do
      assert {:error, _reason, _} =
               Nodes.create_file(
                 ctx.repo1.id,
                 "/",
                 ctx.blob1.id
               )
    end

    test "creating a file should succeed", ctx do
      assert {:ok, _} =
               Nodes.create_file(
                 ctx.repo1.id,
                 "/A/B/file1",
                 ctx.blob1.id
               )
    end

    test "creating files with the same path in distinct repos should succeed", ctx do
      assert {:ok, _} =
               Nodes.create_file(
                 ctx.repo1.id,
                 "/A/B/file1",
                 ctx.blob1.id
               )

      assert {:ok, _} =
               Nodes.create_file(
                 ctx.repo2.id,
                 "/A/B/file1",
                 ctx.blob1.id
               )
    end

    test "creating multuple files in the same directory should succeed", ctx do
      assert {:ok, _} =
               Nodes.create_file(
                 ctx.repo1.id,
                 "/A/B/file1",
                 ctx.blob1.id
               )

      assert {:ok, _} =
               Nodes.create_file(
                 ctx.repo1.id,
                 "/A/B/file2",
                 ctx.blob2.id
               )
    end

    test "creating multuple files at different levels should succeed", ctx do
      assert {:ok, _} =
               Nodes.create_file(
                 ctx.repo1.id,
                 "/A/B/file1",
                 ctx.blob1.id
               )

      assert {:ok, _} =
               Nodes.create_file(
                 ctx.repo1.id,
                 "/A/file1",
                 ctx.blob1.id
               )
    end

    test "replacing a file should fail", ctx do
      assert {:ok, _} =
               Nodes.create_file(
                 ctx.repo1.id,
                 "/A/file1",
                 ctx.blob1.id
               )

      assert {:error, _, _node} =
               Nodes.create_file(
                 ctx.repo1.id,
                 "/A/file1",
                 ctx.blob2.id
               )
    end

    test "explicitly replacing a file should succeed and have delete/create semantic", ctx do
      assert {:ok, %{id: original_id}} =
               Nodes.create_file(
                 ctx.repo1.id,
                 "/A/file1",
                 ctx.blob1.id
               )

      assert {:ok, %{id: new_id, blob_id: blob_id}} =
               Nodes.create_file(
                 ctx.repo1.id,
                 "/A/file1",
                 ctx.blob2.id,
                 replace: true
               )

      refute new_id == original_id
      assert blob_id == ctx.blob2.id
    end
  end

  describe "create_file with properties" do
    setup [:create_repositories, :create_blobs]

    test "creating a file with properties should succeed and have properties attached to the file",
         ctx do
      set_props = %{
        "tag" => "tag1",
        "description" => "file1 description"
      }

      assert {:ok, _} =
               Nodes.create_file(
                 ctx.repo1.id,
                 "/A/file1",
                 ctx.blob1.id,
                 properties: set_props
               )

      assert set_props ==
               Nodes.get_file(ctx.repo1.id, "/A/file1")
               |> NodeProperties.get_properties()
    end

    test "creating a file with properties should not change parent directory properties",
         ctx do
      set_props = %{
        "tag" => "tag1",
        "description" => "file1 description"
      }

      assert {:ok, _} =
               Nodes.create_file(
                 ctx.repo1.id,
                 "/A/file1",
                 ctx.blob1.id,
                 properties: set_props
               )

      assert %{} ==
               Nodes.get(ctx.repo1.id, "/A")
               |> NodeProperties.get_properties()
    end

    test "replacing a file should replace properties", ctx do
      original_props = %{
        "tag" => "tag1",
        "description" => "file1 description"
      }

      new_props = %{
        "tag" => "tag2",
        "changed" => "2021-01-01"
      }

      Nodes.create_file(
        ctx.repo1.id,
        "/A/file1",
        ctx.blob1.id,
        properties: original_props
      )

      {:ok, _node} =
        Nodes.create_file(
          ctx.repo1.id,
          "/A/file1",
          ctx.blob2.id,
          properties: new_props,
          replace: true
        )

      assert new_props ==
               Nodes.get_file(ctx.repo1.id, "/A/file1")
               |> NodeProperties.get_properties()
    end

    test "get a single existing property", ctx do
      set_props = %{
        "tag" => "tag1",
        "description" => "file1 description"
      }

      {:ok, node} =
        Nodes.create_file(
          ctx.repo1.id,
          "/A/file1",
          ctx.blob1.id,
          properties: set_props
        )

      assert "tag1" == NodeProperties.get_property(node, "tag")
      refute NodeProperties.get_property(node, "tag2")
    end

    test "add new property", ctx do
      set_props = %{
        "tag" => "tag1",
        "description" => "file1 description"
      }

      {:ok, node} =
        Nodes.create_file(
          ctx.repo1.id,
          "/A/file1",
          ctx.blob1.id,
          properties: set_props
        )

      NodeProperties.put_property(node, "created_on", "2025-01-01")

      assert "tag1" == NodeProperties.get_property(node, "tag")
      assert "2025-01-01" == NodeProperties.get_property(node, "created_on")
    end

    test "change existing property", ctx do
      set_props = %{
        "tag" => "tag1",
        "description" => "file1 description"
      }

      {:ok, node} =
        Nodes.create_file(
          ctx.repo1.id,
          "/A/file1",
          ctx.blob1.id,
          properties: set_props
        )

      assert "tag1" == NodeProperties.get_property(node, "tag")

      NodeProperties.put_property(node, "tag", "new tag")

      assert "new tag" == NodeProperties.get_property(node, "tag")
    end

    test "delete property", ctx do
      set_props = %{
        "tag" => "tag1",
        "description" => "file1 description"
      }

      {:ok, node} =
        Nodes.create_file(
          ctx.repo1.id,
          "/A/file1",
          ctx.blob1.id,
          properties: set_props
        )

      NodeProperties.delete_property(node, "description")
      refute NodeProperties.get_property(node, "description")
    end
  end

  describe "create_directory with properties" do
    setup [:create_repositories, :create_blobs]

    test "creating a directory with properties should succeed and have properties attached to the directory",
         ctx do
      set_props = %{
        "tag" => "tag1",
        "description" => "dir1 description"
      }

      assert {:ok, _} =
               Nodes.create_directory(
                 ctx.repo1.id,
                 "/A/dir1",
                 properties: set_props
               )

      assert set_props ==
               Nodes.get(ctx.repo1.id, "/A/dir1")
               |> NodeProperties.get_properties()
    end

    @tag skip: "Still uses old code to create nodes"
    test "creating a directory with properties should not change parent directory properties",
         ctx do
      set_props = %{
        "tag" => "tag1",
        "description" => "dir1 description"
      }

      assert {:ok, _} =
               Nodes.create_directory(
                 ctx.repo1.id,
                 "/A/dir1",
                 properties: set_props
               )

      assert %{} ==
               Nodes.get(ctx.repo1.id, "/A")
               |> NodeProperties.get_properties()
    end
  end
end

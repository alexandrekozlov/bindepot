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

  def create_repositories(_context) do
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

  def create_blobs(_context) do
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

  describe "create_directory" do
    setup [:create_repositories]

    test "create a non-directory should fail", context do
      assert {:error, _reason, _node} =
               Nodes.create_directory(
                 context.repo1.id,
                 "/"
               )
    end

    test "create a subdirectories one by one should succeed in all cases", context do
      assert {:ok, _} =
               Nodes.create_directory(
                 context.repo1.id,
                 "/A"
               )

      assert {:ok, _} =
               Nodes.create_directory(
                 context.repo1.id,
                 "/A/B"
               )

      assert {:ok, _} =
               Nodes.create_directory(
                 context.repo1.id,
                 "/A/B/C"
               )

      assert {:ok, _} =
               Nodes.create_directory(
                 context.repo1.id,
                 "/A/B/D"
               )
    end
  end

  describe "create_file" do
    setup [:create_repositories, :create_blobs]

    test "creating file with empty path should fail", context do
      assert {:error, _reason, _} =
               Nodes.create_file(
                 context.repo1.id,
                 "/",
                 context.blob1.id
               )
    end

    test "creating file should succeed", context do
      assert {:ok, _} =
               Nodes.create_file(
                 context.repo1.id,
                 "/A/B/file1",
                 context.blob1.id
               )
    end

    test "creating files with the same path in distinct repos should succeed", context do
      assert {:ok, _} =
               Nodes.create_file(
                 context.repo1.id,
                 "/A/B/file1",
                 context.blob1.id
               )

      assert {:ok, _} =
               Nodes.create_file(
                 context.repo2.id,
                 "/A/B/file1",
                 context.blob1.id
               )
    end

    test "creating multuple files at the same path should succeed", context do
      assert {:ok, _} =
               Nodes.create_file(
                 context.repo1.id,
                 "/A/B/file1",
                 context.blob1.id
               )

      assert {:ok, _} =
               Nodes.create_file(
                 context.repo1.id,
                 "/A/B/file2",
                 context.blob2.id
               )
    end

    test "creating multuple files at different levels should succeed", context do
      assert {:ok, _} =
               Nodes.create_file(
                 context.repo1.id,
                 "/A/B/file1",
                 context.blob1.id
               )

      assert {:ok, _} =
               Nodes.create_file(
                 context.repo1.id,
                 "/A/file1",
                 context.blob1.id
               )
    end

    test "replacing file should succeed", context do
      assert {:ok, _} =
               Nodes.create_file(
                 context.repo1.id,
                 "/A/file1",
                 context.blob1.id
               )

      assert {:ok, _} =
               Nodes.create_file(
                 context.repo1.id,
                 "/A/file1",
                 context.blob1.id
               )
    end

    test "creating file with properties", context do
      set_props =
        %{"tag" => "tag1", "description" => "file1 description"}

      assert {:ok, _} =
               Nodes.create_file(
                 context.repo1.id,
                 "/A/file1",
                 context.blob1.id,
                 properties: set_props
               )

      props =
        Nodes.get_file(context.repo1.id, "/A/file1")
        |> NodeProperties.get_properties()

      assert set_props == props
    end

    test "get single existing property", context do
      set_props =
        %{"tag" => "tag1", "description" => "file1 description"}

      {:ok, node} =
        Nodes.create_file(
          context.repo1.id,
          "/A/file1",
          context.blob1.id,
          properties: set_props
        )

      assert "tag1" == NodeProperties.get_property(node, "tag")
      assert is_nil(NodeProperties.get_property(node, "tag2"))
    end

    test "add new property", context do
      set_props =
        %{"tag" => "tag1", "description" => "file1 description"}

      {:ok, node} =
        Nodes.create_file(
          context.repo1.id,
          "/A/file1",
          context.blob1.id,
          properties: set_props
        )

      NodeProperties.put_property(node, "created_on", "2025-01-01")

      assert "tag1" == NodeProperties.get_property(node, "tag")
      assert "2025-01-01" == NodeProperties.get_property(node, "created_on")
    end

    test "change existing property", context do
      set_props =
        %{"tag" => "tag1", "description" => "file1 description"}

      {:ok, node} =
        Nodes.create_file(
          context.repo1.id,
          "/A/file1",
          context.blob1.id,
          properties: set_props
        )

      assert "tag1" == NodeProperties.get_property(node, "tag")
      NodeProperties.put_property(node, "tag", "new tag")
      assert "new tag" == NodeProperties.get_property(node, "tag")
    end

    test "delete property", context do
      set_props =
        %{"tag" => "tag1", "description" => "file1 description"}

      {:ok, node} =
        Nodes.create_file(
          context.repo1.id,
          "/A/file1",
          context.blob1.id,
          properties: set_props
        )

      NodeProperties.delete_property(node, "description")
      assert is_nil(NodeProperties.get_property(node, "description"))
    end
  end
end

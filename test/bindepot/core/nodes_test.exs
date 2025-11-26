defmodule Bindepot.Core.NodesTest do
  use Bindepot.DataCase

  alias Bindepot.Core.Nodes

  describe "nodes_from_path" do
    test "empty path should return no nodes" do
      assert [] = Nodes.nodes_from_path("")
    end

    test "root path should return no nodes" do
      assert [] = Nodes.nodes_from_path("/")
    end

    test "single root element returns one node" do
      assert [{"/", "A"}] = Nodes.nodes_from_path("/A")
    end

    test "two elements return two nodes in reverse order" do
      assert [{"/A", "B"}, {"/", "A"}] = Nodes.nodes_from_path("/A/B")
    end

    test "three elements return three nodes in reverse order" do
      assert [{"/A/B", "C"}, {"/A", "B"}, {"/", "A"}] = Nodes.nodes_from_path("/A/B/C")
    end

    test "relative paths treated as absolute path" do
      assert [{"/A/B", "C"}, {"/A", "B"}, {"/", "A"}] = Nodes.nodes_from_path("A/B/C")
    end

    test "empty elements ignored" do
      assert [{"/A/B", "C"}, {"/A", "B"}, {"/", "A"}] = Nodes.nodes_from_path("/A//B/C")
    end

    test "trailing separator ignored" do
      assert [{"/A/B", "C"}, {"/A", "B"}, {"/", "A"}] = Nodes.nodes_from_path("/A/B/C/")
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

    test "create a non-directory should succeed", context do
      assert {:ok, []} =
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
  end
end

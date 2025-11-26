defmodule Bindepot.Core.NodeTest do
  use Bindepot.DataCase

  alias Bindepot.Core.Node

  @repo_id_1 UUID.string_to_binary!("00000000-0000-0000-0000-000000000001")

  @blob_id_1 UUID.string_to_binary!("00000000-0000-0000-0000-000000000042")

  test "directory spec should succeed" do
    assert Node.changeset(%Node{}, %{
             path: "/",
             name: "A",
             type: 0,
             repository_id: @repo_id_1
           }).valid?
  end

  test "missing path is an error" do
    refute Node.changeset(%Node{}, %{
             name: "A",
             type: 0,
             repository_id: @repo_id_1
           }).valid?
  end

  test "missing name is an error" do
    refute Node.changeset(%Node{}, %{
             path: "/",
             type: 0,
             repository_id: @repo_id_1
           }).valid?
  end

  test "missing type is an error" do
    refute Node.changeset(%Node{}, %{
             path: "/",
             name: "A",
             repository_id: @repo_id_1
           }).valid?
  end

  test "missing repository is an error" do
    refute Node.changeset(%Node{}, %{
             path: "/",
             name: "A",
             type: 0
           }).valid?
  end

  test "fail if file node is missing blob_id" do
    refute Node.changeset(%Node{}, %{
             path: "/",
             name: "A",
             type: 1,
             repository_id: @repo_id_1
           }).valid?
  end

  test "file node requires blob_id" do
    assert Node.changeset(%Node{}, %{
             path: "/",
             name: "A",
             type: 1,
             blob_id: @blob_id_1,
             repository_id: @repo_id_1
           }).valid?
  end

  test "node type change is an error" do
    refute Node.changeset(
             %Node{
               path: "/",
               name: "A",
               type: 0,
               repository_id: @repo_id_1
             },
             %{
               path: "/",
               name: "A",
               type: 1,
               blob_id: @blob_id_1,
               repository_id: @repo_id_1
             }
           ).valid?
  end

  test "node path change is an error" do
    refute Node.changeset(
             %Node{
               path: "/",
               name: "A",
               type: 0,
               repository_id: @repo_id_1
             },
             %{
               path: "/A",
               name: "A",
               type: 0,
               repository_id: @repo_id_1
             }
           ).valid?
  end

  test "node name change is an error" do
    refute Node.changeset(
             %Node{
               path: "/",
               name: "A",
               type: 0,
               repository_id: @repo_id_1
             },
             %{
               path: "/",
               name: "B",
               type: 0,
               repository_id: @repo_id_1
             }
           ).valid?
  end
end

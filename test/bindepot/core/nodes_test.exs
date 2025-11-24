defmodule Bindepot.Core.NodesTest do
  use Bindepot.DataCase

  alias Bindepot.Core.Nodes

  test "gen_nodes_recursively" do
    Nodes.nodes_from_path([]) |> IO.inspect()
    Nodes.nodes_from_path(["A"]) |> IO.inspect()
    Nodes.nodes_from_path(["A", "B", "C", "D"]) |> IO.inspect()
  end

  test "generate_nodes directory" do
    assert [
             %{path: "/", name: "A", type: 0, repository_id: 123},
             %{path: "/A", name: "B", type: 0, repository_id: 123},
             %{path: "/A/B", name: "C", type: 0, repository_id: 123},
             %{path: "/A/B/C", name: "D", type: 0, repository_id: 123}
           ] =
             Nodes.generate_nodes(123, "/A/B/C/D")
  end

  test "generate_nodes file" do
    assert [
             %{path: "/", name: "A", type: 0, repository_id: 123},
             %{path: "/A", name: "B", type: 0, repository_id: 123},
             %{path: "/A/B", name: "C", type: 0, repository_id: 123},
             %{path: "/A/B/C", name: "D", type: 0, repository_id: 123, blob_id: 42}
           ] =
             Nodes.generate_nodes(123, "/A/B/C/D", 42)
  end

  test "generate_nodes empty path" do
    assert [] =
             Nodes.generate_nodes(123, "")
  end

  test "generate_nodes empty path with blob" do
    assert [] =
             Nodes.generate_nodes(123, "", 42)
  end

  test "generate_nodes root path" do
    assert [] =
             Nodes.generate_nodes(123, "/")
  end

  test "generate_nodes root path with blob" do
    assert [] =
             Nodes.generate_nodes(123, "/", 42)
  end

  test "generate_nodes directory at root" do
    assert [
             %{path: "/", name: "A", type: 0, repository_id: 123}
           ] =
             Nodes.generate_nodes(123, "/A")
  end

  test "generate_nodes file at root" do
    assert [
             %{path: "/", name: "A", type: 0, repository_id: 123, blob_id: 42}
           ] =
             Nodes.generate_nodes(123, "/A", 42)
  end

  test "generate_nodes single element relative directory" do
    assert [
             %{path: "/", name: "A", type: 0, repository_id: 123}
           ] =
             Nodes.generate_nodes(123, "A")
  end

  test "generate_nodes single element relative file" do
    assert [
             %{path: "/", name: "A", type: 0, repository_id: 123, blob_id: 42}
           ] =
             Nodes.generate_nodes(123, "A", 42)
  end

  test "mkdir relative path to directory" do
    assert [
             %{path: "/", name: "A", type: 0, repository_id: 123},
             %{path: "/A", name: "B", type: 0, repository_id: 123},
             %{path: "/A/B", name: "C", type: 0, repository_id: 123}
           ] =
             Nodes.generate_nodes(123, "A/B/C")
  end

  test "mkdir relative path to file" do
    assert [
             %{path: "/", name: "A", type: 0, repository_id: 123},
             %{path: "/A", name: "B", type: 0, repository_id: 123},
             %{path: "/A/B", name: "C", type: 0, repository_id: 123, blob_id: 42}
           ] =
             Nodes.generate_nodes(123, "A/B/C", 42)
  end
end

defmodule Bindepot.Pypi.PackageIndexParserTest do
  use ExUnit.Case, async: true

  alias Bindepot.Pypi.HtmlIndexParser

  describe "extract/0" do
    test "extracts a single anchor" do
      html = ~S(<a href="pkg.whl">Package</a>)

      result =
        [html]
        |> HtmlIndexParser.extract()

      assert [
               %{
                 uri: "pkg.whl",
                 name: "Package",
                 hash: nil
               }
             ] = result
    end

    test "extracts multiple anchors" do
      html = """
      <a href="a1.whl">A1</a>
      <a href="a2.whl">A2</a>
      """

      result =
        [html]
        |> HtmlIndexParser.extract()

      assert [
               %{uri: "a1.whl", name: "A1", hash: nil, metadata: %{}},
               %{uri: "a2.whl", name: "A2", hash: nil, metadata: %{}}
             ] = result
    end

    test "ignores invalid anchors" do
      html = """
      <a href="a1.whl">A1</a>
      <a xhref="a2.whl">A2</a>
      <a>A3</a>
      <a href="test.whl"></a>
      <a href="a3.whl">A3</a>
      """

      result =
        [html]
        |> HtmlIndexParser.extract()

      assert [
               %{uri: "a1.whl", name: "A1", hash: nil, metadata: %{}},
               # %{uri: nil, name: "A2", hash: nil, metadata: %{"xhref" => "a2.whl"}},
               # %{uri: "test.whl", name: "", hash: nil, metadata: %{}},
               %{uri: "a3.whl", name: "A3", hash: nil, metadata: %{}}
             ] = result
    end

    test "extracts anchor split across chunks" do
      stream = [
        "<a href=\"pa",
        "rt1.whl\">PKG</a>"
      ]

      result = HtmlIndexParser.extract(stream)

      assert [
               %{
                 uri: "part1.whl",
                 name: "PKG"
               }
             ] = result
    end

    test "handles attributes in any order" do
      html = ~S(<a data-x="1" rel="nofollow" href="ordered.whl">X</a>)

      [entry] = HtmlIndexParser.extract([html])

      assert entry.uri == "ordered.whl"
      assert entry.name == "X"

      assert entry.metadata["data-x"] == "1"
      assert entry.metadata["rel"] == "nofollow"
    end

    test "extracts hash digest from fragment" do
      html = ~S(<a href="pkg.whl#sha256=abcdef1234">PKG</a>)

      [entry] = HtmlIndexParser.extract([html])

      assert entry.uri == "pkg.whl#sha256=abcdef1234"
      assert entry.hash == {"sha256", "abcdef1234"}
    end

    test "extracts all attributes" do
      html = ~S(<a href="x.whl" data-a="123" data-b="456">X</a>)

      [entry] = HtmlIndexParser.extract([html])

      assert entry.metadata["data-a"] == "123"
      assert entry.metadata["data-b"] == "456"
    end
  end
end

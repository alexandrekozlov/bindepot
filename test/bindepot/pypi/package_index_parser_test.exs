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
                 href: "pkg.whl",
                 content: "Package",
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
               %{href: "a1.whl", content: "A1", hash: nil, attrs: %{}},
               %{href: "a2.whl", content: "A2", hash: nil, attrs: %{}}
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
               %{href: "a1.whl", content: "A1", hash: nil, attrs: %{}},
               %{href: "a3.whl", content: "A3", hash: nil, attrs: %{}}
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
                 href: "part1.whl",
                 content: "PKG"
               }
             ] = result
    end

    test "handles attributes in any order" do
      html = ~S(<a data-x="1" rel="nofollow" href="ordered.whl">X</a>)

      [entry] = HtmlIndexParser.extract([html])

      assert entry.href == "ordered.whl"
      assert entry.content == "X"

      assert entry.attrs["data-x"] == "1"
      assert entry.attrs["rel"] == "nofollow"
    end

    test "extracts hash digest from fragment" do
      html = ~S(<a href="pkg.whl#sha256=abcdef1234">PKG</a>)

      [entry] = HtmlIndexParser.extract([html])

      assert entry.href == "pkg.whl#sha256=abcdef1234"

      assert entry.hash == %{
               algo: "sha256",
               digest: "abcdef1234"
             }
    end

    test "extracts all attributes" do
      html = ~S(<a href="x.whl" data-a="123" data-b="456">X</a>)

      [entry] = HtmlIndexParser.extract([html])

      assert entry.attrs["data-a"] == "123"
      assert entry.attrs["data-b"] == "456"
    end
  end
end

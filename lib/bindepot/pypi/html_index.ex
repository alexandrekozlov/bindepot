defmodule Bindepot.Pypi.HtmlIndex do
  def to_html_repo_simple_index(repo_index) do
    [~s"\t</body>\n</html>\n"]
    |> then(&[Enum.map(repo_index, fn e -> to_html_repo_index_entry(e) <> "<br>\n" end) | &1])
    |> then(&[~s"<!DOCTYPE html>\n<html>\n\t<body>" | &1])
  end

  def to_html_repo_index_entry(%{name: name, uri: uri}) do
    ~s(<a href="#{uri}">#{name}</a>)
  end

  def to_html_package_index_entry(%{name: name, uri: uri, hash: {algo, digest}}) do
    ~s(<a href="#{uri}\##{algo}=#{digest}">#{name}</a>)
  end
end

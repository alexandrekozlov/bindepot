defmodule Bindepot.Pypi.RepoIndex do
  alias Bindepot.Core.Packages
  alias Bindepot.Core.DistFiles
  alias Bindepot.Pypi.HtmlIndexParser

  def get_local_repo_index(repository_id) do
    repository_id
    |> Packages.all()
    |> Enum.map(&%{name: &1.name, uri: &1.name <> "/"})
    |> Enum.sort(&(&1.name >= &2.name))
  end

  def get_local_package_index(repository_id, package_name) do
    repository_id
    |> DistFiles.all(package_name)
    |> Enum.map(&%{name: &1.name, uri: &1.name, hash: {"sha256", &1.blob.sha256}})
    |> Enum.sort(&(&1.name >= &2.name))
  end

  def to_html_repo_simple_index(repo_index) do
    [~s"\t</body>\n</html>\n"]
    |> then(&[Enum.map(repo_index, fn e -> to_html_repo_index_entry(e) <> "<br>\n" end) | &1])
    |> then(&[~s"<!DOCTYPE html>\n<html>\n\t<body>" | &1])
  end

  def to_html_repo_index_entry(%{name: name, uri: uri}) do
    ~s(<a href="#{uri}">#{name}</a>)
  end

  def to_html_repo_index_entry(%{name: name, uri: uri, hash: nil}) do
    ~s(<a href="#{uri}">#{name}</a>)
  end

  def to_html_package_index_entry(%{name: name, uri: uri, hash: {algo, digest}}) do
    ~s(<a href="#{uri}\##{algo}=#{digest}">#{name}</a>)
  end

  def extract_repo_index(stream) do
    stream
    |> HtmlIndexParser.extract()
    |> Enum.reduce([], fn element, acc ->
      [%{name: element.content, uri: element.href} | acc]
    end)
  end
end

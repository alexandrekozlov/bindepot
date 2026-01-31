defmodule Bindepot.Pypi.HtmlIndex do

  # We are sorting entries, which is techincally not necessary, but convenient
  def to_html_repo_simple_index(repo_index) do
    [~s"\t</body>\n</html>\n"]
    |> then(&[(Map.values(repo_index) |> Enum.sort(fn a, b -> a.name < b.name end) |> Enum.map(fn e -> to_html_repo_index_entry(e) <> "<br>\n" end)) | &1])
    |> then(&[~s"<!DOCTYPE html>\n<html>\n\t<body>" | &1])
  end

  # TODO: Figure out why are there atom vs string mix in index entries. Probably parsed vs decoded from JSON.
  def to_html_repo_index_entry(%{"name" => name, "uri" => uri, "metadata" => metadata}) do
    ~s(<a href="#{uri}" #{generate_metadata(metadata)}>#{name}</a>)
  end

  def to_html_repo_index_entry(%{name: name, uri: uri, metadata: metadata}) do
    ~s(<a href="#{uri}" #{generate_metadata(metadata)}>#{name}</a>)
  end

  def to_html_package_index_entry(%{name: name, uri: uri, hash: {algo, digest}}) do
    ~s(<a href="#{uri}\##{algo}=#{digest}">#{name}</a>)
  end

  def generate_metadata(metadata) do
    Enum.reduce(metadata, "", fn {k,v},s -> ~s(#{k}="#{v} ") <> s end)
  end
end

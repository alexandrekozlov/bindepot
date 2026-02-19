defmodule Bindepot.Pypi.HtmlIndex do
  # We are sorting entries, which is techincally not necessary, but convenient
  def to_html_repo_simple_index(repo_index) do
    [~s"\t</body>\n</html>\n"]
    |> then(
      &[
        repo_index
        |> Enum.sort(fn a, b -> a.name < b.name end)
        |> Enum.map(fn e -> to_html_repo_index_entry(e) <> "<br>\n" end)
        | &1
      ]
    )
    |> then(&[~s"<!DOCTYPE html>\n<html>\n\t<body>" | &1])
  end

  def to_html_repo_project_index(project_index, url_base) do
    [~s"\t</body>\n</html>\n"]
    |> then(
      &[
        project_index
        |> Enum.sort(fn a, b -> a.name < b.name end)
        |> Enum.map(fn e -> to_html_project_index_entry(e, url_base) <> "<br>\n" end)
        | &1
      ]
    )
    |> then(&[~s"<!DOCTYPE html>\n<html>\n\t<body>" | &1])
  end

  def to_html_repo_index_entry(%{name: name, uri: uri} = entry) do
    ~s(<a href="#{uri}" #{generate_metadata(Map.get(entry, :metadata))}>#{name}</a>)
  end

  def to_html_project_index_entry(
        %{
          name: name,
          uri: uri,
          hash: {algo, digest}
        } = entry,
        url_base
      ) do
    url = URI.merge(URI.parse(url_base), uri)

    ~s(<a href="#{url}\##{algo}=#{digest}" #{generate_metadata(Map.get(entry, :metadata))}>#{name}</a>)
  end

  def generate_metadata(nil) do
    ""
  end

  def generate_metadata(metadata) do
    Enum.reduce(metadata, "", fn {k, v}, s -> ~s(#{k}="#{v} ") <> s end)
  end
end

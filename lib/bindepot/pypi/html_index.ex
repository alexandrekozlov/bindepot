defmodule Bindepot.Pypi.HtmlIndex do
  require Logger

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

  def to_html_repo_project_index(project_index, url_base, prefix \\ "") do
    [~s"\t</body>\n</html>\n"]
    |> then(
      &[
        project_index
        |> Enum.sort(fn a, b -> a.name < b.name end)
        |> Enum.map(fn e -> to_html_project_index_entry(e, url_base, prefix) <> "<br>\n" end)
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
          repository: repo,
          name: name,
          uri: uri,
          hash: {algo, digest}
        } = entry,
        url_base,
        prefix \\ ""
      ) do
    url = make_resource_url(url_base, repo, uri, prefix)

    ~s(<a href="#{url}\##{algo}=#{digest}" #{generate_metadata(Map.get(entry, :metadata))}>#{name}</a>)
  end

  def generate_metadata(nil) do
    ""
  end

  def generate_metadata(metadata) do
    Enum.reduce(metadata, "", fn {k, v}, s -> ~s(#{k}="#{v} ") <> s end)
  end

  defp make_resource_url(url_base, repo, uri, prefix \\ "") do
    b = URI.parse(url_base)
    p = URI.parse(prefix)
    u = URI.parse(uri)

    case u.host do
      nil ->
        if is_nil(p.path) do
          URI.merge(b, u)
        else
          b
            |> URI.merge(p)
            |> URI.append_path("/" <> repo)
            |> URI.append_path(u.path)
        end

      _h ->
        u
    end
  end
end

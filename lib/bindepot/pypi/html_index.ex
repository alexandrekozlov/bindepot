defmodule Bindepot.Pypi.HtmlIndex do
  # We are sorting entries, which is techincally not necessary, but convenient
  def to_html_repo_simple_index(repo_index) do
    [~s"\t</body>\n</html>\n"]
    |> then(
      &[
        Map.values(repo_index)
        |> Enum.sort(fn a, b -> a.name < b.name end)
        |> Enum.map(fn e -> to_html_repo_index_entry(e) <> "<br>\n" end)
        | &1
      ]
    )
    |> then(&[~s"<!DOCTYPE html>\n<html>\n\t<body>" | &1])
  end

  def to_html_repo_package_index(package_index) do
    [~s"\t</body>\n</html>\n"]
    |> then(
      &[
        Map.values(package_index)
        |> Enum.sort(fn a, b -> a.name < b.name end)
        |> Enum.map(fn e -> to_html_package_index_entry(e) <> "<br>\n" end)
        | &1
      ]
    )
    |> then(&[~s"<!DOCTYPE html>\n<html>\n\t<body>" | &1])
  end

  # TODO: Fix atom vs string mix in keys. The Jason.decode returns strings, where index parser or local repos return atoms.
  # Important points:
  #   1. Cannot just use atoms when deoding with Jason, as it poses a security threat (atom table exhaustion)
  #   2. Cannot convert to strings, unless willing to convert the local repo index too. This is important
  #      for merging the remote and local indices for virtual repository.
  # Having well known keys as atoms has certain advantage, so one way out of it is to use a custom function for
  # Jason.decode(..., keys: key_fn), that will return atoms for known keys and strings for others.
  def to_html_repo_index_entry(%{"name" => name, "uri" => uri, "metadata" => metadata}) do
    ~s(<a href="#{uri}" #{generate_metadata(metadata)}>#{name}</a>)
  end

  def to_html_repo_index_entry(%{name: name, uri: uri, metadata: metadata}) do
    ~s(<a href="#{uri}" #{generate_metadata(metadata)}>#{name}</a>)
  end

  def to_html_package_index_entry(%{
        name: name,
        uri: uri,
        hash: {algo, digest},
        metadata: metadata
      }) do
    ~s(<a href="#{uri}\##{algo}=#{digest}" #{generate_metadata(metadata)}>#{name}</a>)
  end

  def to_html_package_index_entry(%{
        "name" => name,
        "uri" => uri,
        "hash" => {algo, digest},
        "metadata" => metadata
      }) do
    ~s(<a href="#{uri}\##{algo}=#{digest}" #{generate_metadata(metadata)}>#{name}</a>)
  end

  def generate_metadata(metadata) do
    Enum.reduce(metadata, "", fn {k, v}, s -> ~s(#{k}="#{v} ") <> s end)
  end
end

defmodule Bindepot.Pypi.RepoIndex do
  alias Bindepot.PyPI.HtmlIndexParser

  defstruct [:package, :uri]

  def extract_repo_index(stream) do
    stream
    |> HtmlIndexParser.extract()
    |> Enum.reduce([], fn element, acc ->
      [%Bindepot.Pypi.RepoIndex{package: element.content, uri: element.href} | acc]
    end)
  end

  def merge_repo_index() do
  end
end

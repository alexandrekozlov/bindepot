defmodule Bindepot.Core.FilestoresTest do
  use Bindepot.DataCase

  alias Bindepot.Core.Filestores

  test "store and retrieve file" do
    assert {:ok, path} =
             Filestores.default()
             |> Filestores.store(Path.expand("./test/data/artifact.txt"))

    assert {:ok, full_path} =
             Filestores.default()
             |> Filestores.retrieve(path)

    assert File.exists?(full_path)
  end
end

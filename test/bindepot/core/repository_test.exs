defmodule Bindepot.Core.RepositoryTest do
  use Bindepot.DataCase

  test "create_repository" do
    {status, id} =
      Bindepot.Core.Repositories.create(%{
        name: "test",
        repository_type: :local,
        package_type: "generic"
      })

    assert status == :ok
  end
end

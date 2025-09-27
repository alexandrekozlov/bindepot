defmodule Bindepot.Core.RepositoryTest do
  use Bindepot.DataCase

  test "create_repository" do
    {status, id} = Bindepot.Core.Repository.create_repository("test", :local, "pypi", %{}, %{})
    assert status == :ok

  end
end

defmodule Bindepot.Core.RepositoryTest do
  use Bindepot.DataCase

  alias Bindepot.Core.Repositories
  alias Bindepot.Core.Assets

  describe "all/1" do
    setup do
      repository = %{
        name: "generic",
        type: "local",
        package_type: "generic"
      }

      %{repository: repository}
    end

    test "list repos when there are none" do
      assert Repositories.all() == []
    end

    test "list active repos", %{repository: repository} do
      Repositories.create(repository)
      assert [%{name: "generic"}] = Repositories.all()
    end

    test "do not list deleted repos", %{repository: repository} do
      Repositories.create(repository)
      assert [%{name: "generic"} = repo] = Repositories.all()
      Repositories.delete(repo.id)
      assert Repositories.all() == []
    end

    test "list deleted repos", %{repository: repository} do
      Repositories.create(repository)
      [repo] = Repositories.all()
      Repositories.delete(repo.id)
      [%{name: name}] = Repositories.all_deleted()
      assert name =~ ~r/generic\$.+/
    end
  end

  describe "create/1" do
    test "create local repository" do
      now = NaiveDateTime.utc_now()

      assert {:ok, repository} =
               Repositories.create(%{
                 name: "generic",
                 type: "local",
                 package_type: "generic"
               })

      assert %{name: "generic", type: "local", package_type: "generic"} = repository

      assert repository.id != nil
      assert repository.url == nil
      assert repository.repositories == nil

      assert_within_seconds(repository.inserted_at, now)
      assert_within_seconds(repository.updated_at, now)
      assert repository.deleted_at == nil
    end

    test "create remote repository" do
      now = NaiveDateTime.utc_now()

      assert {:ok, repository} =
               Repositories.create(%{
                 name: "generic",
                 type: "remote",
                 package_type: "generic",
                 url: "http://ftp.zymeworks.com"
               })

      assert %{
               name: "generic",
               type: "remote",
               package_type: "generic",
               url: "http://ftp.zymeworks.com"
             } =
               repository

      assert repository.id != nil
      assert repository.repositories == nil

      assert_within_seconds(repository.inserted_at, now)
      assert_within_seconds(repository.updated_at, now)
      assert repository.deleted_at == nil
    end
  end
end

defmodule Bindepot.Core.DistFiles do
  import Ecto.Query, warn: false
  alias Bindepot.Repo

  alias Bindepot.Core.Package
  alias Bindepot.Core.Version
  alias Bindepot.Core.DistFile
  alias Bindepot.Core.Node

  def create_new(name, mime_type, version, package_name, package_type, %Node{} = node) do
    pkg = %{name: package_name, type: package_type}
    ver = %{version: version, package: pkg}

    # TODO: This works, but creates new packages (and versions), instead of reusing them.
    # This goes undetected due to missing constraints on packages name and version (name).
    # create_old will work better for this scenario.
    {:ok, dist_file} =
      %DistFile{}
      |> DistFile.changeset(%{name: name, mime_type: mime_type, version: ver})
      |> Ecto.Changeset.put_assoc(:node, node)
      |> Repo.insert_or_update()

    dist_file
  end

  def create(name, mime_type, version, package_name, package_type, %Node{} = node) do
    # Repo.transact(fn ->
    {:ok, pkg} =
      (Repo.get_by(Package, name: package_name, type: package_type) || %Package{})
      |> Package.changeset(%{name: package_name, type: package_type})
      |> Repo.insert_or_update()
      |> IO.inspect()

    {:ok, ver} =
      (Repo.get_by(Version, package_id: pkg.id, version: version) || %Version{})
      |> IO.inspect()
      |> Repo.preload([:package])
      |> Version.changeset(%{version: version})
      |> IO.inspect()
      |> Ecto.Changeset.put_assoc(:package, pkg)
      |> Repo.insert_or_update()
      |> IO.inspect()

    {:ok, dist_file} =
      (Repo.one(from d in DistFile, where: d.name==^name and d.version_id==^ver.id and d.node_id==^node.id) || %DistFile{}) |> IO.inspect()
      |> Repo.preload([:version, :node])
      |> DistFile.changeset(%{name: name, mime_type: mime_type})
      |> Ecto.Changeset.put_assoc(:version, ver)
      |> Ecto.Changeset.put_assoc(:node, node)
      |> Repo.insert_or_update()

    dist_file
    #  {:ok, dist_file}
    # end)
  end
end

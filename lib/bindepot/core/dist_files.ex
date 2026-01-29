defmodule Bindepot.Core.DistFiles do
  import Ecto.Query, warn: false
  alias Bindepot.Repo

  alias Bindepot.Core.Package
  alias Bindepot.Core.Version
  alias Bindepot.Core.DistFile
  alias Bindepot.Core.Node

  def all(repository_id, package_name) do
    q =
      from p in Package,
        inner_join: v in Version,
        on: p.id == v.package_id,
        inner_join: f in DistFile,
        on: v.id == f.version_id,
        inner_join: n in Node,
        on: f.node_id == n.id,
        where: n.repository_id == ^repository_id and p.name == ^package_name,
        select: n,
        preload: [:blobs]

    Repo.all(q)
  end

  def create(name, mime_type, version, package_name, package_type, %Node{} = node) do
    # Repo.transact(fn ->
    {:ok, pkg} =
      (Repo.get_by(Package, name: package_name, type: package_type) || %Package{})
      |> Package.changeset(%{name: package_name, type: package_type})
      |> Repo.insert_or_update()

    {:ok, ver} =
      (Repo.get_by(Version, package_id: pkg.id, version: version) || %Version{})
      |> Repo.preload([:package])
      |> Version.changeset(%{version: version})
      |> Ecto.Changeset.put_assoc(:package, pkg)
      |> Repo.insert_or_update()

    {:ok, dist_file} =
      (Repo.one(
         from d in DistFile,
           where: d.name == ^name and d.version_id == ^ver.id and d.node_id == ^node.id
       ) || %DistFile{})
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

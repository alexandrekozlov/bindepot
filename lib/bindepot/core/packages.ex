defmodule Bindepot.Core.Packages do
  import Ecto.Query, warn: false
  alias Bindepot.Repo

  alias Bindepot.Core.Package
  alias Bindepot.Core.Version
  alias Bindepot.Core.DistFile
  alias Bindepot.Core.Node

  def all() do
    Repo.all(Package)
  end

  def all(repository_id) do
    q =
      from p in Package,
        inner_join: v in Version,
        on: p.id == v.package_id,
        inner_join: f in DistFile,
        on: v.id == f.version_id,
        inner_join: n in Node,
        on: f.node_id == n.id,
        where: n.repository_id == ^repository_id,
        select: p,
        distinct: p.name

    Repo.all(q)
  end

  def create_package(name, type) do
    %Package{}
    |> Package.changeset(%{name: name, type: type})
    |> Repo.insert()
  end
end

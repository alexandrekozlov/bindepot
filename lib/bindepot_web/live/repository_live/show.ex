defmodule BindepotWeb.RepositoryLive.Show do
  use BindepotWeb, :live_view

  import Ecto.Query
  alias Bindepot.Core.Assets
  alias Bindepot.Core.Repositories

  @impl true
  def mount(%{"id" => id}, _session, socket) do
    vrepo = Repositories.get(id)
    vrepos = vrepo.repositories
    query = from r in Bindepot.Core.Repository, where: r.id in ^vrepos

    subrepos = Bindepot.Repo.all(query)

    {:ok,
     socket
     |> assign(:page_title, "Show Repository")
     |> assign(:repository, vrepo)
     |> assign(:subrepos, subrepos)
     |> assign(:assets, Assets.all(vrepo))}
  end
end

defmodule BindepotWeb.RepositoryLive.Index do
  use BindepotWeb, :live_view

  alias Bindepot.Core.Repositories

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:page_title, "Listing Repositories")
     |> stream(:repositories, list_repositories())
     |> stream(:deleted_repositories, list_deleted_repositories())}
  end

  @impl true
  def handle_event("delete", %{"id" => id}, socket) do
    repository = Repositories.get(id)
    {:ok, _} = Repositories.delete(repository)

    {:noreply, stream_delete(socket, :repositories, repository)}
  end

  @impl true
  def handle_event("purge", %{"id" => id}, socket) do
    repository = Repositories.get(id, allow_deleted: true)
    {:ok, _} = Repositories.purge(repository)
    {:noreply, stream_delete(socket, :deleted_repositories, repository)}
  end

  defp list_repositories() do
    Repositories.all()
  end

  defp list_deleted_repositories() do
    Repositories.deleted()
  end
end

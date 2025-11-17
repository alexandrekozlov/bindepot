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
    {:ok, deleted_repository} = Repositories.delete(repository.id)

    socket =
      socket
      |> stream_delete(:repositories, repository)
      |> stream_insert(:deleted_repositories, deleted_repository)

    {:noreply, socket}
  end

  @impl true
  def handle_event("purge", %{"id" => id}, socket) do
    repository = Repositories.get_deleted(id)

    case Repositories.purge(repository.id) do
      {:ok, _} ->
        {:noreply, stream_delete(socket, :deleted_repositories, repository)}

      _ ->
        {:noreply, socket}
    end
  end

  defp list_repositories() do
    Repositories.all()
  end

  defp list_deleted_repositories() do
    Repositories.all_deleted()
  end
end

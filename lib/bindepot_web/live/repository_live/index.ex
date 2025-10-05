defmodule BindepotWeb.RepositoryLive.Index do
  use BindepotWeb, :live_view

  alias Bindepot.Core.Repositories

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:page_title, "Listing Repositories")
     |> stream(:repositories, list_repositories())}
  end

  @impl true
  def handle_event("delete", %{"id" => id}, socket) do
    repository = Repositories.get_repository!(id)
    {:ok, _} = Repositories.delete_repository(repository)

    {:noreply, stream_delete(socket, :repositories, repository)}
  end

  defp list_repositories() do
    Repositories.list_repositories()
  end
end

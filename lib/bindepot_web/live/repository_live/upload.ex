defmodule BindepotWeb.RepositoryLive.Upload do
  use BindepotWeb, :live_view

  alias Bindepot.Core.Repositories

  @impl true
  def mount(%{"id" => id}, _session, socket) do
    repo = Repositories.get(id)

    {:ok,
     socket
     |> assign(:repository, repo)}
  end
end

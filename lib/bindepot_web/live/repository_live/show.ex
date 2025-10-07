defmodule BindepotWeb.RepositoryLive.Show do
  use BindepotWeb, :live_view

  alias Bindepot.Core.Repositories

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash}>
      <.header>
        Repository {@repository.id}
        <:subtitle>This is a repository record from your database.</:subtitle>
        <:actions>
          <.button navigate={~p"/ui/repositories"}>
            <.icon name="hero-arrow-left" />
          </.button>
          <.button variant="primary" navigate={~p"/ui/repositories/#{@repository}/edit?return_to=show"}>
            <.icon name="hero-pencil-square" /> Edit repository
          </.button>
        </:actions>
      </.header>

      <.list>
        <:item title="Name">{@repository.name}</:item>
      </.list>
    </Layouts.app>
    """
  end

  @impl true
  def mount(%{"id" => id}, _session, socket) do
    {:ok,
     socket
     |> assign(:page_title, "Show Repository")
     |> assign(:repository, Repositories.get(id))}
  end
end

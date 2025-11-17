defmodule BindepotWeb.RepositoryLive.Form do
  use BindepotWeb, :live_view

  alias Bindepot.Core.Repositories
  alias Bindepot.Core.Repository

  @impl true
  def mount(params, _session, socket) do
    {:ok,
     socket
     |> assign(:return_to, return_to(params["return_to"]))
     |> apply_action(socket.assigns.live_action, params)}
  end

  defp return_to("show"), do: "show"
  defp return_to(_), do: "index"

  defp apply_action(socket, :new, _params) do
    repository = %Repository{}

    socket
    |> assign(:page_title, "New Repository")
    |> assign(:repository, repository)
    |> assign(:form, to_form(Ecto.Changeset.change(repository, %{})))
    |> assign(:repository_types, Repository.repository_types())
    |> assign(:package_types, Bindepot.PackageAdapters.package_types())
    |> assign(:repositories, all_but_self_repositories(nil))
    |> assign(:show_url, false)
    |> assign(:show_repositories, false)
  end

  defp apply_action(socket, :edit, %{"id" => id}) do
    repository = Repositories.get(id)

    socket
    |> assign(:page_title, "Edit Repository")
    |> assign(:repository, repository)
    |> assign(:form, to_form(Repository.update_changeset(repository, %{})))
    |> assign(:repositories, all_but_self_repositories(repository.package_type, repository))
    |> assign(:repository_types, Repository.repository_types())
    |> assign(:package_types, Bindepot.PackageAdapters.package_types())
    |> assign(:show_url, Repository.remote?(repository))
    |> assign(:show_repositories, Repository.virtual?(repository))
  end

  @impl true
  def handle_event("validate", %{"repository" => repository_params}, socket) do
    changeset =
      Repository.change(socket.assigns.repository, socket.assigns.live_action, repository_params)

    package_type = Ecto.Changeset.get_field(changeset, :package_type)

    socket =
      socket
      |> assign(:repositories, all_but_self_repositories(package_type, socket.assigns.repository))

    {:noreply,
     assign(socket,
       form: to_form(changeset, action: :validate),
       show_url: Repository.remote?(changeset),
       show_repositories: Repository.virtual?(changeset)
     )}
  end

  def handle_event("save", %{"repository" => repository_params}, socket) do
    save_repository(socket, socket.assigns.live_action, repository_params)
  end

  defp all_but_self_repositories(package_type, self \\ nil) do
    repos =
      case package_type do
        nil ->
          Repositories.all()

        _ ->
          Repositories.all_of_package_type(package_type)
      end

    rs = for r <- repos, do: {r.name, r.id}

    if is_nil(self) do
      rs
    else
      List.keydelete(rs, self.id, 1)
    end
  end

  defp save_repository(socket, :edit, repository_params) do
    case Repositories.update(socket.assigns.repository, repository_params) do
      {:ok, repository} ->
        {:noreply,
         socket
         |> put_flash(:info, "Repository updated successfully")
         |> push_navigate(to: return_path(socket.assigns.return_to, repository))}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, form: to_form(changeset))}
    end
  end

  defp save_repository(socket, :new, repository_params) do
    IO.inspect(repository_params)

    case Repositories.create(repository_params) do
      {:ok, repository} ->
        {:noreply,
         socket
         |> put_flash(:info, "Repository created successfully")
         |> push_navigate(to: return_path(socket.assigns.return_to, repository))}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, form: to_form(changeset))}
    end
  end

  defp return_path("index", _repository), do: ~p"/ui/repositories"
  defp return_path("show", repository), do: ~p"/ui/repositories/#{repository}"
end

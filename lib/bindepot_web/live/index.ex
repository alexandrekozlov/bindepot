defmodule BindepotWeb.ItemLive.Index do
  use BindepotWeb, :live_view

  @repo_types ["local", "remote", "virtual"]
  def get_repo_types, do: @repo_types

  @package_types ["generic", "pypi", "rpm"]
  def get_package_types, do: @package_types

  @impl true
  def mount(_params, _session, socket) do
    # fetch initial list from your context (replace with your real function)
    items = safe_list_items()

    socket =
      socket
      |> assign(:items, items)
      |> assign(:show_form, false)
      |> assign(:form_data, %{
        "name" => "",
        "repository_type" => "local",
        "package_type" => "generic"
      })

    {:ok, socket}
  end

  @impl true
  def handle_event("new", _payload, socket) do
    {:noreply, assign(socket, show_form: true)}
  end

  def handle_event("cancel", _payload, socket) do
    {:noreply, assign(socket, show_form: false)}
  end

  def handle_event("save", %{"item" => params}, socket) do
    # route to your context. we attempt to call create_item/1 and then reload list.
    case safe_create_item(params) do
      {:ok, _item} ->
        items = safe_list_items()
        {:noreply, socket |> assign(:items, items) |> assign(:show_form, false)}

      {:error, _reason} ->
        # keep the form shown — you can add flash or validation handling here
        {:noreply, socket |> assign(:show_form, true)}
    end
  end

  # --- Helpers that call your context but stay tolerant if functions are missing ---
  defp safe_list_items do
    Bindepot.Core.Repositories.all()
  end

  defp safe_create_item(params) do
    params =
      Enum.reduce(params, %{}, fn {key, value}, acc ->
        if is_atom(key) do
          Map.put(acc, Atom.to_string(key), value)
        else
          Map.put(acc, key, value)
        end
      end)

    IO.inspect(params)
    {:ok, repo} = Bindepot.Core.Repositories.create(params)
    {:ok, Map.put(params, "id", repo.id)}
  end
end

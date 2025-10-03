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
      |> assign(:form_data, %{"name" => "", "repository_type" => "local", "package_type" => "generic"})

    {:ok, socket}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="container mx-auto p-6">
      <h1 class="text-2xl font-bold mb-4">Bindepot — Items</h1>

      <div class="mb-4">
        <button phx-click="new" class="rounded bg-blue-600 text-white px-3 py-1">Create item</button>
      </div>

      <%= if @show_form do %>
        <div class="mb-4 p-4 border rounded-lg">
          <.form for={@form_data} phx-submit="save">
            <div class="mb-2">
              <label class="block text-sm font-medium">Name</label>
              <input name="item[name]" value={@form_data["name"]} class="border rounded w-full p-2" />
            </div>

            <div class="mb-2">
              <label class="block text-sm font-medium">Repository type</label>
              <select name="item[repository_type]" class="border rounded w-full p-2">
                <%= for t <- get_repo_types() do %>
                  <option selected={t == @form_data["repository_type"]}>{t}</option>
                <% end %>
              </select>
            </div>

            <div class="mb-2">
              <label class="block text-sm font-medium">Other value</label>
              <select name="item[package_type]" class="border rounded w-full p-2">
                <%= for v <- get_package_types() do %>
                  <option selected={v == @form_data["package_type"]}>{v}</option>
                <% end %>
              </select>
            </div>

            <div class="flex gap-2 mt-3">
              <button type="submit" class="rounded bg-green-600 text-white px-3 py-1">Save</button>
              <button type="button" phx-click="cancel" class="rounded bg-gray-300 px-3 py-1">
                Cancel
              </button>
            </div>
          </.form>
        </div>
      <% end %>

      <div>
        <table class="w-full border-collapse">
          <thead>
            <tr class="text-left border-b">
              <th class="py-2">ID</th>
              <th class="py-2">Name</th>
              <th class="py-2">Type</th>
              <th class="py-2">Other</th>
            </tr>
          </thead>
          <tbody>
            <%= for item <- @items do %>
              <tr class="border-b">
                <td class="py-2">{Map.get(item, :id) || Map.get(item, "id")}</td>
                <td class="py-2">{Map.get(item, :name) || Map.get(item, "name")}</td>
                <td class="py-2">{Map.get(item, :repository_type) || Map.get(item, "repository_type")}</td>
                <td class="py-2">{Map.get(item, :package_type) || Map.get(item, "package_type")}</td>
              </tr>
            <% end %>
          </tbody>
        </table>
      </div>
    </div>
    """
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
    Bindepot.Core.Repositories.list_repositories()
  end

  defp safe_create_item(params) do
    params = Enum.reduce(params, %{}, fn {key, value}, acc ->
      if is_atom(key) do
        Map.put(acc, Atom.to_string(key), value)
      else
        Map.put(acc, key, value)
      end
    end)
    IO.inspect(params)
    {:ok, repo} = Bindepot.Core.Repositories.create_repository(params)
    Map.put(params, "id", repo.id)
  end
end

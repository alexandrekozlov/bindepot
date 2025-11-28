defmodule BindepotWeb.Api.Utils do
  def sanitize_schema(list) when is_list(list) do
    f = fn e ->
      Map.from_struct(e)
      |> remove_not_loaded_associations()
      |> Map.delete(:__meta__)
    end

    Enum.map(list, f)
  end

  def sanitize_schema(repo) when is_struct(repo) do
    repo
    |> Map.from_struct()
    |> remove_not_loaded_associations()
    |> remove_meta()
    #|> Map.delete(:__meta__)
  end

  defp remove_meta(map) do
    Enum.reduce(map, %{}, fn {key, value}, acc ->
      cond do
        key == :__meta__ ->
          acc
        is_map(value) ->
          Map.put(acc, key, remove_meta(value))
        true ->
          Map.put(acc, key, value)
      end
    end)
  end

  defp remove_not_loaded_associations(map) do
    map
    |> Enum.reduce(%{}, fn {key, value}, acc ->
      if is_struct(value, Ecto.Association.NotLoaded) do
        acc
      else
        if is_struct(value) do
          v= Map.from_struct(value)
          |> remove_not_loaded_associations()
          Map.put(acc, key, v)
        else
          Map.put(acc, key, value)
        end
      end
    end)
  end
end

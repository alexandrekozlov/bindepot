defmodule Bindepot.Core.Hasher do
  def hash_init(hash_functions) do
    Enum.reduce(hash_functions, %{}, fn hash_func, states ->
      Map.put_new(states, hash_func, :crypto.hash_init(hash_func))
    end)
  end

  def hash_update(states, data) do
    Enum.reduce(states, %{}, fn {key, state}, acc ->
      Map.put_new(acc, key, :crypto.hash_update(state, data))
    end)
  end

  def hash_final(states) do
    Enum.reduce(states, %{}, fn {key, state}, acc ->
      Map.put_new(acc, key, :crypto.hash_final(state))
    end)
  end

  def to_string(digests) do
    Enum.reduce(digests, %{}, fn {key, digest}, acc ->
      Map.put_new(acc, key, Base.encode16(digest, case: :lower))
    end)
  end
end

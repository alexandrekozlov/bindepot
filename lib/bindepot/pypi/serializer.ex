defmodule Bindepot.Pypi.Serializer do
  @moduledoc """
  Utilities for serializing Elixir terms to files and reading them back.
  """

  @doc """
  Serializes any Elixir term to a file using `:erlang.term_to_binary/1`.

  Options:
    * `:compress` - integer 0..9 (default: 0). Higher means more compression.

  Returns:
    * `:ok` on success
    * `{:error, reason}` on failure
  """
  @spec to_file(term(), Path.t(), keyword()) :: :ok | {:error, term()}
  def to_file(term, path, opts \\ []) when is_list(opts) do
    compress = Keyword.get(opts, :compress, 0)
    binary = :erlang.term_to_binary(term, [{:compressed, compress}])

    with :ok <- ensure_dir(path) do
      File.write(path, binary)
    end
  end

  @doc """
  Reads a previously serialized term from a file created by `to_file/3`.
  """
  @spec from_file(Path.t()) :: {:ok, term()} | {:error, term()}
  def from_file(path) do
    case File.read(path) do
      {:ok, binary} ->
        try do
          {:ok, :erlang.binary_to_term(binary)}
        rescue
          e -> {:error, e}
        end

      {:error, reason} ->
        {:error, reason}
    end
  end

  # Ensures the directory for the file exists.
  defp ensure_dir(path) do
    path
    |> Path.dirname()
    |> File.mkdir_p()
  end
end

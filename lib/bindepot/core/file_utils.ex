defmodule Bindepot.Core.FileUtils do
  alias Bindepot.Core.Hasher

  @doc """
    Moves a file by either renaming if source and destination are on the same
    filesystem or copy/delete if on different filesystems. Both source and
    destination are file names.

    Both `src` and `dst` are file names.
  """
  @spec move_file(String.t(), String.t()) :: :ok | {:error, File.posix()}
  def move_file(src, dst) do
    case is_same_fs(src, Path.dirname(dst)) do
      # both locations are on the same filesystem, can move
      true ->
        File.rename(src, dst)

      # source and destination on different filesystems. copy/delete
      false ->
        with :ok <- File.cp(src, dst) do
          # ignore result as we only care that file ended up where we wanted.
          File.rm(src)
          :ok
        else
          {:error, posix} ->
            {:error, posix}
        end

      {:error, posix} ->
        {:error, posix}
    end
  end

  @doc """
    Returns true if both source and destination are on the same filesystem.
  """
  def is_same_fs(src, dst) do
    with {:ok, s_stat} <- File.stat(src),
         {:ok, d_stat} <- File.stat(Path.dirname(dst)) do
      s_stat.major_device == s_stat.minor_device and
        d_stat.major_device == d_stat.minor_device
    else
      {:error, posix} ->
        {:error, posix}
    end
  end

  @doc ~S"""
    Takes an enumerable `stream` and a `path` and writes all data chunks into
    the file at `path`.

    Returns `{:ok, :ok}` on success or `{:error, reason}` on failure.
  """
  def store(stream, path) do
    File.open(path, [:write, :binary], fn fd ->
      Enum.each(stream, &IO.binwrite(fd, &1))
    end)
  end

  def hash(stream, hashes) do
    stream
    |> Enum.reduce(Hasher.init(hashes), &Hasher.update(&2, &1))
    |> Hasher.finalize()
    |> Hasher.to_string()
  end

  def hash_and_store(stream, hashes, path) do
    File.open(path, [:write, :binary], fn fd ->
      stream
      |> Stream.each(&IO.binwrite(fd, &1))
      |> Enum.reduce(Hasher.init(hashes), &Hasher.update(&2, &1))
      |> Hasher.finalize()
      |> Hasher.to_string()
    end)
  end
end

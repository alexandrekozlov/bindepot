defmodule Bindepot.Core.FileUtils do
  alias Bindepot.Core.Hasher

  @doc ~S"""
    Moves a file.

    If source and destination are on the same filesystem then uses `rename/2`.
    If source and destination are on different filesystems, then uses copy/delete.

    Both `src` and `dst` are file names.

    `:create_dir` - when `false`, does not create destination directories (defaults to `true`)

  """
  @spec move_file(String.t(), String.t(), [{:create_dir, boolean()}]) ::
          :ok | {:error, File.posix()}
  def move_file(src, dst, opts \\ []) do
    dst_dir = Path.dirname(dst)

    opts
    |> Keyword.validate!(create_dir: true)
    |> Keyword.get(:create_dir)
    |> do_ensure_dir(dst_dir)

    src
    |> same_fs?(dst_dir)
    |> do_move_file(src, dst)
  end

  @doc """
    Returns true if both source and destination are on the same filesystem.
  """
  def same_fs?(src, dst) do
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

  defp do_ensure_dir(true, dir) do
    File.mkdir_p(dir)
  end

  defp do_ensure_dir(false, _dir) do
    :ok
  end

  defp do_move_file(true = _is_same_fs, src, dst) do
    File.rename(src, dst)
  end

  defp do_move_file(false = _is_same_fs, src, dst) do
    with :ok <- File.cp(src, dst),
         _ <- File.rm(src) do
      :ok
    else
      {:error, posix} ->
        {:error, posix}
    end
  end

  defp do_move_file({:error, posix} = _is_same_fs, _src, _dst) do
    {:error, posix}
  end
end

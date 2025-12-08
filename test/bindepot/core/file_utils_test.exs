defmodule Bindepot.Core.FileUtilsTest do
  use ExUnit.Case

  alias Bindepot.Core.Hasher
  alias Bindepot.Core.FileUtils

  @count 1024

  describe "hashing" do
    setup do
      temp_file = Temp.path!()
      on_exit(fn -> File.rm(temp_file) end)

      %{
        hash:
          Stream.iterate(0, &(&1 + 1))
          |> Enum.take(@count)
          |> Enum.reduce(Hasher.init([:sha]), &Hasher.update(&2, <<&1>>))
          |> Hasher.finalize()
          |> Hasher.to_string(),
        items:
          Stream.iterate(0, &(&1 + 1))
          |> Enum.take(@count)
          |> Enum.map(&<<&1>>),
        size: @count,
        temp_file: temp_file
      }
    end

    test "hash", ctx do
      assert ctx.hash == ctx.items |> FileUtils.hash([:sha])
    end

    test "hash_and_store", ctx do
      assert not File.exists?(ctx.temp_file)
      assert {:ok, ctx.hash} == ctx.items |> FileUtils.hash_and_store([:sha], ctx.temp_file)
      assert File.exists?(ctx.temp_file)
      assert ctx.size == File.stat!(ctx.temp_file).size
      assert IO.iodata_to_binary(ctx.items) == File.read!(ctx.temp_file)
    end

    test "store", ctx do
      assert not File.exists?(ctx.temp_file)
      assert {:ok, :ok} == ctx.items |> FileUtils.store(ctx.temp_file)
      assert File.exists?(ctx.temp_file)
      assert ctx.size == File.stat!(ctx.temp_file).size
      assert IO.iodata_to_binary(ctx.items) == File.read!(ctx.temp_file)
    end
  end
end

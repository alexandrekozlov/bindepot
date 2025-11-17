defmodule Bindepot.Core.HasherTest do
  use ExUnit.Case

  alias Bindepot.Core.Hasher

  test "hasher" do
    digests =
      Hasher.hash_init([:md5, :sha])
      |> Hasher.hash_update("TestString")
      |> Hasher.hash_final()

    assert Base.encode16(Map.get(digests, :md5), case: :lower) ==
             "5b56f40f8828701f97fa4511ddcd25fb"
  end
end

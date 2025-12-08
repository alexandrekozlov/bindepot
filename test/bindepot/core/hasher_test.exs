defmodule Bindepot.Core.HasherTest do
  use ExUnit.Case

  alias Bindepot.Core.Hasher

  test "hasher" do
    digests =
      Hasher.init([:md5, :sha])
      |> Hasher.update("TestString")
      |> Hasher.finalize()

    assert Base.encode16(Map.get(digests, :md5), case: :lower) ==
             "5b56f40f8828701f97fa4511ddcd25fb"
  end
end

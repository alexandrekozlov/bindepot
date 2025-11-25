defmodule Bindepot.Core.BlobTest do
  use Bindepot.DataCase

  alias Bindepot.Core.Blob

  describe "blob" do
    test "missing size and sha256 is an error" do
      refute Blob.changeset(%Blob{}, %{}).valid?
    end

    test "missing size is an error" do
      refute Blob.changeset(%Blob{}, %{sha256: "sha-hash"}).valid?
    end

    test "missing sha256 is an error" do
      refute Blob.changeset(%Blob{}, %{size: 42}).valid?
    end

    test "missing non essential fields is ok" do
      assert Blob.changeset(%Blob{}, %{size: 1024, sha256: "sha256-hash"}).valid?
    end

    test "complete blob is ok" do
      assert Blob.changeset(%Blob{}, %{
               size: 1024,
               md5: "md5-hash",
               sha1: "sha1-hash",
               sha256: "sha256-hash",
               blake2: "blake2-hash"
             }).valid?
    end

    test "mismatched size is an error" do
      refute Blob.changeset(%Blob{size: 42}, %{
               size: 1024,
               sha256: "sha256-hash"
             }).valid?
    end

    test "mismatched hash is an error" do
      refute Blob.changeset(%Blob{size: 42, sha256: "sha256-hash"}, %{
               size: 42,
               sha256: "bad-sha256-hash"
             }).valid?
    end

    test "same size and hash is ok" do
      assert Blob.changeset(%Blob{size: 42, sha256: "sha256-hash"}, %{
               size: 42,
               sha256: "sha256-hash"
             }).valid?
    end

    test "all hashes validated" do
      assert [
               blake2: _,
               md5: _,
               sha1: _,
               sha256: _
             ] =
               Blob.changeset(
                 %Blob{
                   size: 42,
                   md5: "md5-hash",
                   sha1: "sha1-hash",
                   sha256: "sha256-hash",
                   blake2: "blake2-hash"
                 },
                 %{
                   size: 42,
                   md5: "bad-md5-hash",
                   sha1: "bad-sha1-hash",
                   sha256: "bad-sha256-hash",
                   blake2: "bad-blake2-hash"
                 }
               ).errors
               |> Enum.sort()
    end
  end
end

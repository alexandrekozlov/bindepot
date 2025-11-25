defmodule Bindepot.Core.BlobsTest do
  use Bindepot.DataCase

  alias Bindepot.Core.Blob
  alias Bindepot.Core.Blobs

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

  describe "blob put" do
    test "putting new blob is ok" do
      assert {:ok,
              %{
                id: id,
                size: 256,
                sha256: "d9014c4624844aa5bac314773d6b689ad467fa4e1d1a50a1b8a99d5a95f72ff5"
              }} =
               Blobs.put(%{
                 size: 256,
                 sha256: "d9014c4624844aa5bac314773d6b689ad467fa4e1d1a50a1b8a99d5a95f72ff5"
               })

      refute is_nil(id)
    end

    test "putting same blob is ok" do
      {:ok, %{id: id}} =
        Blobs.put(%{
          size: 256,
          sha256: "d9014c4624844aa5bac314773d6b689ad467fa4e1d1a50a1b8a99d5a95f72ff5"
        })

      assert {:ok,
              %{
                id: ^id,
                size: 256,
                sha256: "d9014c4624844aa5bac314773d6b689ad467fa4e1d1a50a1b8a99d5a95f72ff5"
              }} =
               Blobs.put(%{
                 size: 256,
                 sha256: "d9014c4624844aa5bac314773d6b689ad467fa4e1d1a50a1b8a99d5a95f72ff5"
               })
    end

    test "updating same blob with additional hashes is ok" do
      {:ok, %{id: id}} =
        Blobs.put(%{
          size: 256,
          sha256: "d9014c4624844aa5bac314773d6b689ad467fa4e1d1a50a1b8a99d5a95f72ff5"
        })

      assert {:ok,
              %{
                id: ^id,
                size: 256,
                md5: "746308829575e17c3331bbcb00c0898b",
                sha1: "09fac8dbfd27bd9b4d23a00eb648aa751789536d",
                sha256: "d9014c4624844aa5bac314773d6b689ad467fa4e1d1a50a1b8a99d5a95f72ff5"
              }} =
               Blobs.put(%{
                 size: 256,
                 md5: "746308829575e17c3331bbcb00c0898b",
                 sha1: "09fac8dbfd27bd9b4d23a00eb648aa751789536d",
                 sha256: "d9014c4624844aa5bac314773d6b689ad467fa4e1d1a50a1b8a99d5a95f72ff5"
               })
    end

    test "updating same blob with different hashes should fail" do
      {:ok, %{id: _id}} =
        Blobs.put(%{
          size: 256,
          md5: "746308829575e17c3331bbcb00c0898b",
          sha1: "09fac8dbfd27bd9b4d23a00eb648aa751789536d",
          sha256: "d9014c4624844aa5bac314773d6b689ad467fa4e1d1a50a1b8a99d5a95f72ff5"
        })

      assert {:error, _changeset} =
               Blobs.put(%{
                 size: 256,
                 md5: "ea0806edbc653eb74818123c778f0a9f",
                 sha1: "09fac8dbfd27bd9b4d23a00eb648aa751789536d",
                 sha256: "d9014c4624844aa5bac314773d6b689ad467fa4e1d1a50a1b8a99d5a95f72ff5"
               })
    end

    test "putting blob with same hash but different size should fail" do
      {:ok, %{id: _id}} =
        Blobs.put(%{
          size: 256,
          sha256: "d9014c4624844aa5bac314773d6b689ad467fa4e1d1a50a1b8a99d5a95f72ff5"
        })

      assert {:error, _changeset} =
               Blobs.put(%{
                 size: 42,
                 sha256: "d9014c4624844aa5bac314773d6b689ad467fa4e1d1a50a1b8a99d5a95f72ff5"
               })
    end

    test "putting blob with same size but different hash is ok" do
      {:ok, %{id: id}} =
        Blobs.put(%{
          size: 256,
          sha256: "d9014c4624844aa5bac314773d6b689ad467fa4e1d1a50a1b8a99d5a95f72ff5"
        })

      assert {:ok,
              %{
                id: new_id,
                size: 256,
                sha256: "35f8abff4c16f2a3fc4ed36f0ef45f5ff5858923155847468f09a2f4b42ceedf"
              }} =
               Blobs.put(%{
                 size: 256,
                 sha256: "35f8abff4c16f2a3fc4ed36f0ef45f5ff5858923155847468f09a2f4b42ceedf"
               })

      refute id == new_id
    end

    test "putting differnt blob blob with same hash but different size should fail" do
      {:ok, %{id: _id}} =
        Blobs.put(%{
          size: 256,
          sha256: "d9014c4624844aa5bac314773d6b689ad467fa4e1d1a50a1b8a99d5a95f72ff5"
        })

      assert {:error, _changeset} =
               Blobs.put(%{
                 size: 42,
                 sha256: "d9014c4624844aa5bac314773d6b689ad467fa4e1d1a50a1b8a99d5a95f72ff5"
               })
    end
  end

  describe "blob get" do
    test "get_by_sha256" do
      {:ok, %{id: id}} =
        Blobs.put(%{
          size: 256,
          md5: "746308829575e17c3331bbcb00c0898b",
          sha1: "09fac8dbfd27bd9b4d23a00eb648aa751789536d",
          sha256: "d9014c4624844aa5bac314773d6b689ad467fa4e1d1a50a1b8a99d5a95f72ff5"
        })

      assert %{id: ^id} =
               Blobs.get_by_sha256(
                 "d9014c4624844aa5bac314773d6b689ad467fa4e1d1a50a1b8a99d5a95f72ff5"
               )
    end
  end
end

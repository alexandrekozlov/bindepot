defmodule Bindepot.Core.BlobsTest do
  use Bindepot.DataCase

  alias Bindepot.Core.Blobs

  describe "blob put" do
    test "putting new blob is ok" do
      assert {:ok,
              %{
                id: id,
                size: 256,
                sha256: "d9014c4624844aa5bac314773d6b689ad467fa4e1d1a50a1b8a99d5a95f72ff5"
              },
              :new} =
               Blobs.put(%{
                 size: 256,
                 sha256: "d9014c4624844aa5bac314773d6b689ad467fa4e1d1a50a1b8a99d5a95f72ff5"
               })

      refute is_nil(id)
    end

    test "putting same blob is ok" do
      {:ok, %{id: id}, _} =
        Blobs.put(%{
          size: 256,
          sha256: "d9014c4624844aa5bac314773d6b689ad467fa4e1d1a50a1b8a99d5a95f72ff5"
        })

      assert {:ok,
              %{
                id: ^id,
                size: 256,
                sha256: "d9014c4624844aa5bac314773d6b689ad467fa4e1d1a50a1b8a99d5a95f72ff5"
              },
              :existing} =
               Blobs.put(%{
                 size: 256,
                 sha256: "d9014c4624844aa5bac314773d6b689ad467fa4e1d1a50a1b8a99d5a95f72ff5"
               })
    end

    test "updating same blob with additional hashes is ok" do
      {:ok, %{id: id}, _} =
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
              },
              :existing} =
               Blobs.put(%{
                 size: 256,
                 md5: "746308829575e17c3331bbcb00c0898b",
                 sha1: "09fac8dbfd27bd9b4d23a00eb648aa751789536d",
                 sha256: "d9014c4624844aa5bac314773d6b689ad467fa4e1d1a50a1b8a99d5a95f72ff5"
               })
    end

    test "updating same blob with different hashes should fail" do
      {:ok, %{id: _id}, _} =
        Blobs.put(%{
          size: 256,
          md5: "746308829575e17c3331bbcb00c0898b",
          sha1: "09fac8dbfd27bd9b4d23a00eb648aa751789536d",
          sha256: "d9014c4624844aa5bac314773d6b689ad467fa4e1d1a50a1b8a99d5a95f72ff5"
        })

      assert {:error, _changeset, _} =
               Blobs.put(%{
                 size: 256,
                 md5: "ea0806edbc653eb74818123c778f0a9f",
                 sha1: "09fac8dbfd27bd9b4d23a00eb648aa751789536d",
                 sha256: "d9014c4624844aa5bac314773d6b689ad467fa4e1d1a50a1b8a99d5a95f72ff5"
               })
    end

    test "putting blob with same hash but different size should fail" do
      {:ok, %{id: _id}, _} =
        Blobs.put(%{
          size: 256,
          sha256: "d9014c4624844aa5bac314773d6b689ad467fa4e1d1a50a1b8a99d5a95f72ff5"
        })

      assert {:error, _changeset, _} =
               Blobs.put(%{
                 size: 42,
                 sha256: "d9014c4624844aa5bac314773d6b689ad467fa4e1d1a50a1b8a99d5a95f72ff5"
               })
    end

    test "putting blob with same size but different hash is ok" do
      {:ok, %{id: id}, _} =
        Blobs.put(%{
          size: 256,
          sha256: "d9014c4624844aa5bac314773d6b689ad467fa4e1d1a50a1b8a99d5a95f72ff5"
        })

      assert {:ok,
              %{
                id: new_id,
                size: 256,
                sha256: "35f8abff4c16f2a3fc4ed36f0ef45f5ff5858923155847468f09a2f4b42ceedf"
              },
              :new} =
               Blobs.put(%{
                 size: 256,
                 sha256: "35f8abff4c16f2a3fc4ed36f0ef45f5ff5858923155847468f09a2f4b42ceedf"
               })

      refute id == new_id
    end

    test "putting differnt blob with same hash but different size should fail" do
      {:ok, %{id: _id}, _} =
        Blobs.put(%{
          size: 256,
          sha256: "d9014c4624844aa5bac314773d6b689ad467fa4e1d1a50a1b8a99d5a95f72ff5"
        })

      assert {:error, _changeset, _} =
               Blobs.put(%{
                 size: 42,
                 sha256: "d9014c4624844aa5bac314773d6b689ad467fa4e1d1a50a1b8a99d5a95f72ff5"
               })
    end
  end

  describe "blob get" do
    test "get_by_sha256" do
      {:ok, %{id: id}, _} =
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

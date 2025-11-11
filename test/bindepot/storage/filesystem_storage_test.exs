defmodule Bindepot.Storage.FilesystemStorageTest do
  use Bindepot.DataCase

  alias Bindepot.Storage.FilesystemStorage

  setup do
    Temp.track!()
    []
  end

  test "put file in the storage and get it back" do
    store_root_dir = Temp.mkdir!()
    store = %FilesystemStorage{store_root_directory: store_root_dir}

    assert {:ok, blob_ref} =
             FilesystemStorage.put(
               store,
               Path.expand("./test/data/artifact.txt"),
               UUID.uuid4()
             )

    assert {:ok, file_path} = FilesystemStorage.get(store, blob_ref)
    assert File.exists?(file_path)
  end
end

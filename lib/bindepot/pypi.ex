defmodule Bindepot.Pypi do
  alias Bindepot.Core.Assets
  alias Bindepot.Core.DistFiles

  def publish(repository, file, metadata, _opts \\ []) do
    store_path =
      "/" <>
        Enum.join([metadata.package_name, metadata.package_version, metadata.asset_filename], "/")

    {:ok, node} = Assets.put_file(repository.id, store_path, file, replace: true)

    pkg =
      DistFiles.create(
        metadata.asset_filename,
        "application/octet-stream",
        metadata.package_version,
        metadata.package_name,
        "pypi",
        node
      )

    pkg
  end

  def get_package_metadata(_file) do
  end
end

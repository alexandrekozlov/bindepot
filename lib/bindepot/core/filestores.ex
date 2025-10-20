defmodule Bindepot.Core.Filestores do
  alias Bindepot.Core.Filestore

  def all() do
    [default()]
  end

  def default() do
    %Filestore{
      name: "default",
      provider: to_string(Bindepot.Storage.FilesystemStorage),
      configuration:
        Map.from_struct(%Bindepot.Storage.FilesystemStorage{
          id: "0",
          store_root_directory: data_path()
        })
    }
  end

  def store(%Filestore{} = store, source_file, id \\ UUID.uuid4()) do
    mod = String.to_existing_atom(store.provider)
    provider_config = mod.from_configuration(store.configuration)
    mod.put(provider_config, source_file, id)
  end

  def retrieve(%Filestore{} = store, path) do
    mod = String.to_existing_atom(store.provider)
    provider_config = mod.from_configuration(store.configuration)
    mod.get(provider_config, path)
  end

  defp data_path() do
    Application.get_env(:bindepot, :data_dir)
  end
end

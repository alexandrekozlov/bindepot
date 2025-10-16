defmodule Bindepot.Core.Stores do
  alias Bindepot.Core.Store

  def all() do
    [default()]
  end

  def default() do
    %Store{
      name: "default",
      provider: Bindepot.Storage.LocalStore,
      configuration:
        Map.from_struct(%Bindepot.Storage.LocalStore{
          id: "0",
          store_root_directory: data_path()
        })
    }
  end

  def store(%Store{} = store, source_file) do
    provider_config = store.provider.from_configuration(store.configuration)
    store.provider.store(provider_config, source_file)
  end

  def retrieve(%Store{} = store, path) do
    provider_config = store.provider.from_configuration(store.configuration)
    store.provider.retrieve(provider_config, path)
  end

  defp data_path() do
    Application.get_env(:bindepot, :data_dir)
  end
end

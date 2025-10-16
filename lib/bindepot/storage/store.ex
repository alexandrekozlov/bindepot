defmodule Bindepot.Storage.Store do
  @moduledoc """
  Behaviour for repository storage backends.
  """

  @callback data_dir() :: String.t()
  @callback cache_dir() :: String.t()
  @callback repo_path(binary_id :: String.t()) :: String.t()
  @callback create_repo_dir(binary_id :: String.t()) :: :ok | {:error, any()}
  @callback delete_repo_dir(binary_id :: String.t()) :: :ok | {:error, any()}
  @callback upload_temp_to_final(temp_path :: String.t(), final_path :: String.t()) ::
              :ok | {:error, any()}
  @callback store(temp_file :: String.t()) ::
              {:ok, %Bindepot.Storage.LocalStore{}} | {:error, any()}
end

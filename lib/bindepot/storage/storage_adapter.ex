defmodule Bindepot.Storage.StorageAdapter do
  @moduledoc """
  Behaviour for repository storage backends.
  """

  @callback put(config :: struct() | map(), file_path :: String.t(), id :: String.t()) ::
              {:ok, path :: String.t()} | {:error, reason :: String.t()}

  @callback get(config :: struct() | map(), rel_object_path :: String.t()) ::
              {:ok, String.t()} | {:error, String.t()}
end

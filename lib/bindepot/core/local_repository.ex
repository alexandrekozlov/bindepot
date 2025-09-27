defmodule Bindepot.Core.LocalRepository do
  defstruct [
    :name,
    :repository_type,
    :package_type,
    :description,
    :notes
  ]
end

defmodule Bindepot.Core.RemoteRepository do
  defstruct [
    :name,
    :repository_type,
    :package_type,
    :description,
    :notes,
    :url
  ]
end

defmodule Bindepot.Core.VirtualRepository do
  defstruct [
    :name,
    :repository_type,
    :package_type,
    :description,
    :notes,
    :repositories
  ]
end

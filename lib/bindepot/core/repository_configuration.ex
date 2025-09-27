defmodule Bindepot.Core.RepositoryConfiguration do
  defstruct [
    :description,
    :notes,
    :url,               # applies to repository_type: :remote
    :repositories       # applies to repository_type: :virtual
  ]
end

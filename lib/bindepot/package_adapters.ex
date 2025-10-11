defmodule Bindepot.PackageAdapters do
  @adapters %{
    "pypi" => Bindepot.PyPI.API,
    "npm" => Bindepot.Npm.API,
    "rpm" => Bindepot.Rpm.API,
    "generic" => Bindepot.Generic.API,
    "puppet" => Bindepot.Puppet.API,
    "r" => Bindepot.R.API
  }

  def package_types() do
    Map.keys(@adapters)
  end

  def for_type(type) when is_binary(type), do: Map.get(@adapters, String.downcase(type))
end

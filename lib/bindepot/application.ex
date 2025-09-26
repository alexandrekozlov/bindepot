defmodule Bindepot.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      BindepotWeb.Telemetry,
      Bindepot.Repo,
      {DNSCluster, query: Application.get_env(:bindepot, :dns_cluster_query) || :ignore},
      {Phoenix.PubSub, name: Bindepot.PubSub},
      # Start a worker by calling: Bindepot.Worker.start_link(arg)
      # {Bindepot.Worker, arg},
      # Start to serve requests, typically the last entry
      BindepotWeb.Endpoint
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: Bindepot.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    BindepotWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end

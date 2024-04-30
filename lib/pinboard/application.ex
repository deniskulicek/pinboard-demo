defmodule Pinboard.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      PinboardWeb.Telemetry,
      Pinboard.Repo,
      {DNSCluster, query: Application.get_env(:pinboard, :dns_cluster_query) || :ignore},
      {Phoenix.PubSub, name: Pinboard.PubSub},
      # Start the Finch HTTP client for sending emails
      {Finch, name: Pinboard.Finch},
      # Start a worker by calling: Pinboard.Worker.start_link(arg)
      # {Pinboard.Worker, arg},
      # Start to serve requests, typically the last entry
      PinboardWeb.Endpoint,
      # Presence tracking module
      PinboardWeb.Presence
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: Pinboard.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    PinboardWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end

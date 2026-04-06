defmodule BibleReader.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      BibleReaderWeb.Telemetry,
      BibleReader.Repo,
      {DNSCluster, query: Application.get_env(:biblereader, :dns_cluster_query) || :ignore},
      {Phoenix.PubSub, name: BibleReader.PubSub},
      # Start the Finch HTTP client for sending emails
      {Finch, name: BibleReader.Finch},
      # Start a worker by calling: BibleReader.Worker.start_link(arg)
      # {BibleReader.Worker, arg},
      # Start to serve requests, typically the last entry
      BibleReaderWeb.Endpoint
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: BibleReader.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    BibleReaderWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end

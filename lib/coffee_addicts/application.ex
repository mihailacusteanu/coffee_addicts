defmodule CoffeeAddicts.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    csv_url = Application.get_env(:coffee_addicts, :csv_url)
    start_shop_cache = Application.get_env(:coffee_addicts, :start_shop_cache, true)

    base_children = [
      CoffeeAddictsWeb.Telemetry,
      {DNSCluster, query: Application.get_env(:coffee_addicts, :dns_cluster_query) || :ignore},
      {Phoenix.PubSub, name: CoffeeAddicts.PubSub},
      {Finch, name: CoffeeAddicts.Finch}
    ]

    shop_cache_child =
      if start_shop_cache do
        [{CoffeeAddicts.ShopCache, csv_url: csv_url}]
      else
        []
      end

    children = base_children ++ shop_cache_child ++ [CoffeeAddictsWeb.Endpoint]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: CoffeeAddicts.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    CoffeeAddictsWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end

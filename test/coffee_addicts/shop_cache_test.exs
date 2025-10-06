defmodule CoffeeAddicts.ShopCacheTest do
  use ExUnit.Case, async: false

  alias CoffeeAddicts.ShopCache

  setup do
    csv_content = """
    Shop1,1.0,1.0
    Shop2,2.0,2.0
    Shop3,3.0,3.0
    """

    successful_fetcher = fn _url -> {:ok, csv_content} end

    on_exit(fn ->
      case Process.whereis(ShopCache) do
        nil ->
          :ok

        pid when is_pid(pid) ->
          if Process.alive?(pid) do
            GenServer.stop(ShopCache)
          end
      end

      case Process.whereis(:fetch_state) do
        nil ->
          :ok

        pid when is_pid(pid) ->
          if Process.alive?(pid) do
            Agent.stop(:fetch_state)
          end
      end
    end)

    %{csv_content: csv_content, successful_fetcher: successful_fetcher}
  end

  describe "start_link/1" do
    test "starts the cache with initial CSV fetch", %{successful_fetcher: fetcher} do
      csv_url = "https://example.com/shops.csv"

      assert {:ok, pid} = ShopCache.start_link(csv_url: csv_url, csv_fetcher: fetcher)
      assert Process.alive?(pid)
    end

    test "fetches and caches CSV data on startup", %{successful_fetcher: fetcher} do
      csv_url = "https://example.com/shops.csv"

      {:ok, _pid} = ShopCache.start_link(csv_url: csv_url, csv_fetcher: fetcher)

      assert {:ok, csv_content} = ShopCache.get_csv()
      assert csv_content =~ "Shop1"
    end

    test "returns error when initial fetch fails" do
      failing_fetcher = fn _url -> {:error, {:data_fetcher_timeout, "timeout"}} end
      csv_url = "https://example.com/shops.csv"

      assert {:error, {:data_fetcher_timeout, "timeout"}} =
               ShopCache.start_link(csv_url: csv_url, csv_fetcher: failing_fetcher)
    end
  end

  describe "get_csv/0" do
    test "returns cached CSV content", %{successful_fetcher: fetcher, csv_content: content} do
      {:ok, _pid} =
        ShopCache.start_link(csv_url: "https://example.com/shops.csv", csv_fetcher: fetcher)

      assert {:ok, ^content} = ShopCache.get_csv()
    end

    test "returns same content on multiple calls without refetching", %{
      successful_fetcher: fetcher
    } do
      fetch_tracker = self()

      tracking_fetcher = fn url ->
        send(fetch_tracker, {:fetch_called, url})
        fetcher.(url)
      end

      {:ok, _pid} =
        ShopCache.start_link(
          csv_url: "https://example.com/shops.csv",
          csv_fetcher: tracking_fetcher
        )

      assert_received {:fetch_called, _}

      ShopCache.get_csv()
      ShopCache.get_csv()
      ShopCache.get_csv()

      refute_received {:fetch_called, _}
    end

    test "returns error when cache is not started" do
      assert {:error, :cache_not_available} = ShopCache.get_csv()
    end
  end

  describe "refresh/0" do
    test "refreshes cached CSV data", %{csv_content: initial_content} do
      initial_fetcher = fn _url -> {:ok, initial_content} end
      updated_content = "UpdatedShop,5.0,5.0\n"

      {:ok, _pid} =
        ShopCache.start_link(
          csv_url: "https://example.com/shops.csv",
          csv_fetcher: initial_fetcher
        )

      assert {:ok, ^initial_content} = ShopCache.get_csv()

      updated_fetcher = fn _url -> {:ok, updated_content} end

      assert :ok = ShopCache.refresh(updated_fetcher)

      assert {:ok, ^updated_content} = ShopCache.get_csv()
    end

    test "keeps old data if refresh fails", %{successful_fetcher: fetcher, csv_content: content} do
      {:ok, _pid} =
        ShopCache.start_link(csv_url: "https://example.com/shops.csv", csv_fetcher: fetcher)

      failing_fetcher = fn _url -> {:error, {:data_fetcher_timeout, "timeout"}} end

      assert {:error, {:data_fetcher_timeout, "timeout"}} = ShopCache.refresh(failing_fetcher)

      assert {:ok, ^content} = ShopCache.get_csv()
    end
  end

  describe "scheduled refresh" do
    test "automatically refreshes cache at configured interval" do
      fetch_tracker = self()
      initial_content = "Initial,1.0,1.0\n"
      updated_content = "Updated,2.0,2.0\n"

      Agent.start_link(fn -> :initial end, name: :fetch_state)

      stateful_fetcher = fn url ->
        send(fetch_tracker, {:fetch_called, url})

        state = Agent.get(:fetch_state, & &1)

        case state do
          :updated -> {:ok, updated_content}
          :initial -> {:ok, initial_content}
        end
      end

      refresh_interval = 100

      {:ok, _pid} =
        ShopCache.start_link(
          csv_url: "https://example.com/shops.csv",
          csv_fetcher: stateful_fetcher,
          refresh_interval: refresh_interval
        )

      assert_received {:fetch_called, _}

      Agent.update(:fetch_state, fn _ -> :updated end)

      Process.sleep(refresh_interval + 50)

      assert_received {:fetch_called, _}

      assert {:ok, ^updated_content} = ShopCache.get_csv()

      Agent.stop(:fetch_state)
    end
  end
end

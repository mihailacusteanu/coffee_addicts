defmodule CoffeeAddicts.DataFetcherTest do
  use ExUnit.Case, async: true

  alias CoffeeAddicts.DataFetcher

  describe "fetch_csv/2" do
    test "successfully fetches and returns CSV data from a URL" do
      url = "https://example.com/data.csv"
      csv_content = "name,email\nJohn,john@example.com\nJane,jane@example.com"

      mock_client = fn
        :get, ^url, _opts ->
          {:ok, %Tesla.Env{status: 200, body: csv_content}}
      end

      assert {:ok, ^csv_content} = DataFetcher.fetch_csv(url, http_client: mock_client)
    end

    test "returns error when HTTP request fails" do
      url = "https://example.com/data.csv"

      mock_client = fn
        :get, ^url, _opts ->
          {:error, :timeout}
      end

      assert {:error, {:data_fetcher_timeout, "Request timed out"}} = DataFetcher.fetch_csv(url, http_client: mock_client)
    end

    test "returns error when server responds with non-200 status" do
      url = "https://example.com/data.csv"

      mock_client = fn
        :get, ^url, _opts ->
          {:ok, %Tesla.Env{status: 404, body: "Not Found"}}
      end

      assert {:error, {:data_fetcher_http_error, "You received a 404 code from API"}} = DataFetcher.fetch_csv(url, http_client: mock_client)
    end
  end
end

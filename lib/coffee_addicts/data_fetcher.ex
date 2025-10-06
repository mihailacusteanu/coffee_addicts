defmodule CoffeeAddicts.DataFetcher do
  @moduledoc """
  Fetches CSV data from remote URLs using Tesla HTTP client.
  """

  @doc """
  Fetches CSV data from the given URL.

  ## Parameters
    - url: The URL to fetch CSV data from
    - opts: Keyword list of options
      - :http_client - HTTP client function for dependency injection (default: &__MODULE__.default_client/2)

  ## Returns
    - {:ok, csv_content} on success
    - {:error, {error_type, description}} on failure where error_type is an atom and description is a string

  ## Examples
      iex> DataFetcher.fetch_csv("https://example.com/data.csv")
      {:ok, "name,email\\nJohn,john@example.com"}

      iex> DataFetcher.fetch_csv("https://example.com/data.csv", http_client: mock_client)
      {:ok, "name,email\\nJohn,john@example.com"}
  """
  def fetch_csv(url, opts \\ []) do
    http_client = Keyword.get(opts, :http_client, &__MODULE__.default_client/3)

    case http_client.(:get, url, opts) do
      {:ok, %Tesla.Env{status: 200, body: body}} ->
        {:ok, body}

      {:ok, %Tesla.Env{status: status}} ->
        {:error, {:data_fetcher_http_error, "You received a #{status} code from API"}}

      {:error, :timeout} ->
        {:error, {:data_fetcher_timeout, "Request timed out"}}

      {:error, reason} ->
        {:error, {:data_fetcher_request_failed, "Request failed: #{inspect(reason)}"}}
    end
  end

  @doc false
  def default_client(method, url, _opts) do
    client = Tesla.client([
      Tesla.Middleware.FollowRedirects
    ])

    case method do
      :get -> Tesla.get(client, url)
    end
  end
end

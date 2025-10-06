defmodule CoffeeAddicts.ShopCache do
  @moduledoc """
  GenServer that caches coffee shop CSV data to avoid fetching on every request.
  Supports automatic periodic refresh.
  """

  use GenServer

  alias CoffeeAddicts.DataFetcher

  @default_refresh_interval :timer.minutes(5)

  defmodule State do
    @moduledoc false
    defstruct [:csv_content, :csv_url, :csv_fetcher, :refresh_interval]
  end

  ## Client API

  @doc """
  Starts the ShopCache GenServer.

  ## Options
    - :csv_url - URL to fetch CSV from (required)
    - :csv_fetcher - Function to fetch CSV (default: DataFetcher.fetch_csv/1)
    - :refresh_interval - Auto-refresh interval in ms (default: 5 minutes)
  """
  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
  Gets the cached CSV content.
  """
  @spec get_csv() :: {:ok, String.t()} | {:error, :cache_not_available}
  def get_csv do
    case Process.whereis(__MODULE__) do
      nil -> {:error, :cache_not_available}
      _pid -> GenServer.call(__MODULE__, :get_csv)
    end
  end

  @doc """
  Manually refreshes the cached CSV data.
  """
  @spec refresh((String.t() -> {:ok, String.t()} | {:error, term()}) | nil) ::
          :ok | {:error, term()}
  def refresh(csv_fetcher \\ nil) do
    GenServer.call(__MODULE__, {:refresh, csv_fetcher})
  end

  ## Server Callbacks

  @impl true
  def init(opts) do
    csv_url = Keyword.fetch!(opts, :csv_url)
    csv_fetcher = Keyword.get(opts, :csv_fetcher, &DataFetcher.fetch_csv/1)
    refresh_interval = Keyword.get(opts, :refresh_interval, @default_refresh_interval)

    case fetch_csv_data(csv_fetcher, csv_url) do
      {:ok, csv_content} ->
        state = %State{
          csv_content: csv_content,
          csv_url: csv_url,
          csv_fetcher: csv_fetcher,
          refresh_interval: refresh_interval
        }

        schedule_refresh(refresh_interval)

        {:ok, state}

      {:error, reason} ->
        {:error, reason}
    end
  end

  @impl true
  def handle_call(:get_csv, _from, state) do
    {:reply, {:ok, state.csv_content}, state}
  end

  @impl true
  def handle_call({:refresh, custom_fetcher}, _from, state) do
    fetcher = custom_fetcher || state.csv_fetcher

    case fetch_csv_data(fetcher, state.csv_url) do
      {:ok, new_content} ->
        new_state = %{state | csv_content: new_content, csv_fetcher: fetcher}
        {:reply, :ok, new_state}

      {:error, reason} ->
        {:reply, {:error, reason}, state}
    end
  end

  @impl true
  def handle_info(:refresh, state) do
    case fetch_csv_data(state.csv_fetcher, state.csv_url) do
      {:ok, new_content} ->
        schedule_refresh(state.refresh_interval)
        {:noreply, %{state | csv_content: new_content}}

      {:error, _reason} ->
        schedule_refresh(state.refresh_interval)
        {:noreply, state}
    end
  end

  ## Private Functions

  defp fetch_csv_data(fetcher, url) do
    fetcher.(url)
  end

  defp schedule_refresh(interval) when is_integer(interval) and interval > 0 do
    Process.send_after(self(), :refresh, interval)
  end

  defp schedule_refresh(_), do: :ok
end

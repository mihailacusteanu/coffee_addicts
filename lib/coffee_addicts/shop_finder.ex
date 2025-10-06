defmodule CoffeeAddicts.ShopFinder do
  @moduledoc """
  High-level module that orchestrates finding the closest coffee shops.
  Integrates CSV processing and distance calculation in a parallelized pipeline.
  Handles millions of shops efficiently by processing in batches.
  """

  alias CoffeeAddicts.CsvProcessor
  alias CoffeeAddicts.DistanceCalculator
  alias CoffeeAddicts.ShopCache

  @default_batch_size 100

  @doc """
  Finds the 3 closest coffee shops to the user's coordinates.

  Fetches CSV data from cache and finds the nearest shops.

  ## Parameters
    - user_x: User's X coordinate
    - user_y: User's Y coordinate
    - opts: Keyword list of options
      - :csv_source - Function to fetch CSV (default: ShopCache.get_csv/0)
      - :batch_size - Number of lines to process per batch (default: 100)

  ## Returns
    - {:ok, [%{name: string, x: float, y: float, distance: float}]} - Up to 3 closest shops
    - {:error, {error_type, description}} on failure

  ## Examples
      iex> ShopFinder.find_closest(47.6, -122.4)
      {:ok, [%{name: "Cafe A", x: 47.5, y: -122.3, distance: 0.1414}, ...]}
  """
  @spec find_closest(number(), number(), keyword()) ::
          {:ok, [map()]} | {:error, {atom(), atom() | String.t()}}
  def find_closest(user_x, user_y, opts \\ []) do
    csv_source = Keyword.get(opts, :csv_source, &ShopCache.get_csv/0)

    with {:ok, csv_content} <- csv_source.(),
         {:ok, nearest_shops} <- find_closest_from_csv(csv_content, user_x, user_y, opts) do
      {:ok, nearest_shops}
    else
      {:error, :cache_not_available} -> {:error, {:data_fetch_failed, :cache_unavailable}}
      error -> error
    end
  end

  @doc """
  Finds the 3 closest coffee shops from CSV content.

  Processes the CSV in parallel batches, finds top 3 per batch,
  then merges results to get the global top 3.

  ## Parameters
    - csv_content: String containing CSV data (format: Name,X,Y)
    - user_x: User's X coordinate
    - user_y: User's Y coordinate
    - opts: Keyword list of options
      - :batch_size - Number of lines to process per batch (default: 100)
      - :batch_processor - Function for processing batches (for dependency injection)

  ## Returns
    - {:ok, [%{name: string, x: float, y: float, distance: float}]} - Up to 3 closest shops
    - {:error, {error_type, description}} on failure

  ## Examples
      iex> csv = "Cafe A,1.0,1.0\\nCafe B,2.0,2.0"
      iex> ShopFinder.find_closest_from_csv(csv, 0.0, 0.0)
      {:ok, [%{name: "Cafe A", x: 1.0, y: 1.0, distance: 1.4142}, ...]}
  """
  @spec find_closest_from_csv(String.t(), number(), number(), keyword()) ::
          {:ok, [map()]} | {:error, {atom(), String.t()}}
  def find_closest_from_csv(csv_content, user_x, user_y, opts \\ []) do
    with :ok <- validate_coordinates(user_x, user_y) do
      batch_size = Keyword.get(opts, :batch_size, @default_batch_size)
      batch_processor = Keyword.get(opts, :batch_processor, &process_batch/3)

      global_top_3 =
        csv_content
        |> parse_csv_lines()
        |> process_batches_in_parallel(batch_size, batch_processor, user_x, user_y)
        |> merge_to_global_top_3()

      {:ok, global_top_3}
    end
  end

  defp parse_csv_lines(csv_content) do
    csv_content
    |> String.split("\n", trim: true)
    |> Enum.map(&String.trim/1)
    |> Enum.reject(&(&1 == ""))
  end

  defp process_batches_in_parallel(lines, batch_size, batch_processor, user_x, user_y) do
    lines
    |> Enum.chunk_every(batch_size)
    |> Task.async_stream(fn batch -> batch_processor.(batch, user_x, user_y) end, ordered: false)
    |> Enum.flat_map(fn {:ok, local_top_3} -> [local_top_3] end)
  end

  defp merge_to_global_top_3(local_top_3_lists) do
    local_top_3_lists
    |> List.flatten()
    |> Enum.sort_by(& &1.distance)
    |> Enum.take(3)
  end

  @doc """
  Processes a batch of CSV lines and returns the top 3 closest shops.

  This function is public to allow dependency injection in tests.

  ## Parameters
    - batch: List of CSV line strings
    - user_x: User's X coordinate
    - user_y: User's Y coordinate

  ## Returns
    - List of up to 3 closest shops from this batch with distances
  """
  @spec process_batch([String.t()], number(), number()) :: [map()]
  def process_batch(batch, user_x, user_y) do
    batch
    |> parse_batch_lines()
    |> add_distances(user_x, user_y)
    |> select_top_3()
  end

  defp parse_batch_lines(batch) do
    batch
    |> Enum.map(&CsvProcessor.parse_line/1)
    |> Enum.filter(&match?({:ok, _}, &1))
    |> Enum.map(fn {:ok, shop} -> shop end)
  end

  defp add_distances(shops, user_x, user_y) do
    Enum.map(shops, fn shop ->
      distance = DistanceCalculator.calculate_distance(shop, user_x, user_y)
      shop |> Map.from_struct() |> Map.put(:distance, distance)
    end)
  end

  defp select_top_3(shops_with_distances) do
    shops_with_distances
    |> Enum.sort_by(& &1.distance)
    |> Enum.take(3)
  end

  defp validate_coordinates(user_x, user_y) do
    cond do
      not is_number(user_x) ->
        {:error, {:invalid_coordinates, "User X coordinate must be a number"}}

      not is_number(user_y) ->
        {:error, {:invalid_coordinates, "User Y coordinate must be a number"}}

      true ->
        :ok
    end
  end
end

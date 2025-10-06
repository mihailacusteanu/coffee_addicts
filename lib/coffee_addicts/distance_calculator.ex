defmodule CoffeeAddicts.DistanceCalculator do
  @moduledoc """
  Calculates distances between coffee shops and user coordinates.
  Finds the closest coffee shops to a given location.
  """

  alias CoffeeAddicts.CsvProcessor.CoffeeShop

  @doc """
  Finds the 3 closest coffee shops to the given user coordinates.

  ## Parameters
    - shops: List of %CoffeeShop{} structs
    - user_x: User's X coordinate
    - user_y: User's Y coordinate
    - opts: Keyword list of options
      - :distance_fn - Function for calculating distances (for dependency injection)

  ## Returns
    - {:ok, [%{name: string, x: float, y: float, distance: float}]} - List of up to 3 closest shops with distances
    - {:error, {error_type, description}} on failure

  ## Examples
      iex> shops = [%CoffeeShop{name: "Cafe", x: 1.0, y: 1.0}]
      iex> DistanceCalculator.find_closest(shops, 0.0, 0.0)
      {:ok, [%{name: "Cafe", x: 1.0, y: 1.0, distance: 1.4142}]}
  """
  @spec find_closest([CoffeeShop.t()], number(), number(), keyword()) ::
          {:ok, [map()]} | {:error, {atom(), String.t()}}
  def find_closest(shops, user_x, user_y, opts \\ []) do
    with :ok <- validate_coordinates(user_x, user_y) do
      distance_fn = Keyword.get(opts, :distance_fn, &calculate_distance/3)

      closest =
        shops
        |> calculate_all_distances(user_x, user_y, distance_fn)
        |> sort_by_distance()
        |> take_top_three()

      {:ok, closest}
    end
  end

  defp calculate_all_distances(shops, user_x, user_y, distance_fn) do
    Enum.map(shops, fn shop ->
      distance = distance_fn.(shop, user_x, user_y)
      shop |> Map.from_struct() |> Map.put(:distance, distance)
    end)
  end

  defp sort_by_distance(shops_with_distances) do
    Enum.sort_by(shops_with_distances, & &1.distance)
  end

  defp take_top_three(sorted_shops) do
    Enum.take(sorted_shops, 3)
  end

  @doc """
  Calculates the Euclidean distance between a coffee shop and user coordinates.
  Distance is rounded to 4 decimal places.

  ## Parameters
    - shop: %CoffeeShop{} struct
    - user_x: User's X coordinate
    - user_y: User's Y coordinate

  ## Returns
    - Float representing the distance, rounded to 4 decimal places

  ## Examples
      iex> shop = %CoffeeShop{name: "Test", x: 3.0, y: 4.0}
      iex> DistanceCalculator.calculate_distance(shop, 0.0, 0.0)
      5.0
  """
  @spec calculate_distance(CoffeeShop.t(), number(), number()) :: float()
  def calculate_distance(%CoffeeShop{x: shop_x, y: shop_y}, user_x, user_y) do
    dx = shop_x - user_x
    dy = shop_y - user_y

    :math.sqrt(dx * dx + dy * dy)
    |> Float.round(4)
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

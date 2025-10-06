defmodule CoffeeAddicts.CoordinateParser do
  @moduledoc """
  Parses and validates coordinate parameters.
  """

  @doc """
  Parses coordinates from a params map.

  ## Parameters
    - params: Map containing coordinate parameters

  ## Returns
    - {:ok, {x, y}} on success
    - {:error, {error_type, details}} on failure

  ## Examples
      iex> CoordinateParser.parse(%{"x" => "47.6", "y" => "-122.4"})
      {:ok, {47.6, -122.4}}

      iex> CoordinateParser.parse(%{"y" => "-122.4"})
      {:error, {:missing_param, "x"}}
  """
  @spec parse(map()) :: {:ok, {float(), float()}} | {:error, {atom(), String.t()}}
  def parse(params) do
    with {:ok, x} <- parse_coordinate(params, "x"),
         {:ok, y} <- parse_coordinate(params, "y") do
      {:ok, {x, y}}
    end
  end

  defp parse_coordinate(params, key) do
    with {:ok, value} <- get_param(params, key) do
      parse_float(value, key)
    end
  end

  defp get_param(params, key) do
    case Map.get(params, key) do
      nil -> {:error, {:missing_param, key}}
      value -> {:ok, value}
    end
  end

  defp parse_float(value, key) do
    case Float.parse(value) do
      {float_value, ""} -> {:ok, float_value}
      _ -> {:error, {:invalid_param, key}}
    end
  end
end

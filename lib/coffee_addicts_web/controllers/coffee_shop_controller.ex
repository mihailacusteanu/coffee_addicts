defmodule CoffeeAddictsWeb.CoffeeShopController do
  use CoffeeAddictsWeb, :controller

  alias CoffeeAddicts.CoordinateParser
  alias CoffeeAddicts.ShopFinder

  def nearest(conn, params) do
    csv_source = conn.private[:csv_source]

    opts = if csv_source, do: [csv_source: csv_source], else: []

    with {:ok, {user_x, user_y}} <- CoordinateParser.parse(params),
         {:ok, nearest_shops} <- ShopFinder.find_closest(user_x, user_y, opts) do
      render_success(conn, nearest_shops)
    else
      error -> render_error(conn, error)
    end
  end

  defp render_success(conn, shops) do
    conn
    |> put_status(:ok)
    |> json(%{data: shops})
  end

  defp render_error(conn, {:error, {:missing_param, param}}) do
    conn
    |> put_status(:bad_request)
    |> json(%{error: "Missing required parameter: #{param}"})
  end

  defp render_error(conn, {:error, {:invalid_param, param}}) do
    conn
    |> put_status(:bad_request)
    |> json(%{error: "Invalid parameter: #{param} must be a number"})
  end

  defp render_error(conn, {:error, {:data_fetch_failed, _reason}}) do
    conn
    |> put_status(:service_unavailable)
    |> json(%{error: "Failed to fetch coffee shop data"})
  end

  defp render_error(conn, {:error, {:invalid_coordinates, _message}}) do
    conn
    |> put_status(:bad_request)
    |> json(%{error: "Invalid coordinates provided"})
  end
end

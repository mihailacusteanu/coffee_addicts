defmodule CoffeeAddictsWeb.CoffeeShopControllerTest do
  use CoffeeAddictsWeb.ConnCase, async: true

  describe "GET /api/coffee-shops/nearest" do
    test "returns 3 closest coffee shops with distances", %{conn: conn} do
      user_x = 47.6
      user_y = -122.4

      mock_csv_source = fn ->
        {:ok,
         """
         Starbucks Seattle,47.5809,-122.3160
         Starbucks SF,37.5209,-122.3340
         Starbucks Moscow,55.752047,37.595242
         Starbucks Seattle2,47.5869,-122.3368
         Starbucks Rio,-22.923489,-43.234418
         Starbucks Sydney,-33.871843,151.206767
         """}
      end

      conn =
        conn
        |> Plug.Conn.put_private(:csv_source, mock_csv_source)
        |> get(~p"/api/coffee-shops/nearest?x=#{user_x}&y=#{user_y}")

      assert %{
               "data" => [
                 %{
                   "name" => "Starbucks Seattle2",
                   "x" => 47.5869,
                   "y" => -122.3368,
                   "distance" => first_distance
                 },
                 %{
                   "name" => "Starbucks Seattle",
                   "x" => 47.5809,
                   "y" => -122.3160,
                   "distance" => second_distance
                 },
                 %{
                   "name" => "Starbucks SF",
                   "x" => 37.5209,
                   "y" => -122.3340,
                   "distance" => third_distance
                 }
               ]
             } = json_response(conn, 200)

      assert is_float(first_distance)
      assert is_float(second_distance)
      assert is_float(third_distance)

      assert first_distance < second_distance
      assert second_distance < third_distance

      assert Float.round(first_distance, 4) == first_distance
    end

    test "returns error when x coordinate is missing", %{conn: conn} do
      user_y = -122.4

      conn = get(conn, ~p"/api/coffee-shops/nearest?y=#{user_y}")

      assert %{
               "error" => "Missing required parameter: x"
             } = json_response(conn, 400)
    end

    test "returns error when y coordinate is missing", %{conn: conn} do
      user_x = 47.6

      conn = get(conn, ~p"/api/coffee-shops/nearest?x=#{user_x}")

      assert %{
               "error" => "Missing required parameter: y"
             } = json_response(conn, 400)
    end

    test "returns error when x coordinate is not a number", %{conn: conn} do
      invalid_x = "not_a_number"
      user_y = -122.4

      conn = get(conn, ~p"/api/coffee-shops/nearest?x=#{invalid_x}&y=#{user_y}")

      assert %{
               "error" => "Invalid parameter: x must be a number"
             } = json_response(conn, 400)
    end

    test "returns error when y coordinate is not a number", %{conn: conn} do
      user_x = 47.6
      invalid_y = "not_a_number"

      conn = get(conn, ~p"/api/coffee-shops/nearest?x=#{user_x}&y=#{invalid_y}")

      assert %{
               "error" => "Invalid parameter: y must be a number"
             } = json_response(conn, 400)
    end

    test "returns error when CSV source is unavailable", %{conn: conn} do
      user_x = 47.6
      user_y = -122.4

      failing_csv_source = fn ->
        {:error, :cache_not_available}
      end

      conn =
        conn
        |> Plug.Conn.put_private(:csv_source, failing_csv_source)
        |> get(~p"/api/coffee-shops/nearest?x=#{user_x}&y=#{user_y}")

      assert %{
               "error" => "Failed to fetch coffee shop data"
             } = json_response(conn, 503)
    end

    test "returns empty list when CSV has no valid entries", %{conn: conn} do
      user_x = 47.6
      user_y = -122.4

      mock_csv_source = fn ->
        {:ok,
         """
         Invalid,not,a,number
         Also Invalid
         """}
      end

      conn =
        conn
        |> Plug.Conn.put_private(:csv_source, mock_csv_source)
        |> get(~p"/api/coffee-shops/nearest?x=#{user_x}&y=#{user_y}")

      assert %{
               "data" => []
             } = json_response(conn, 200)
    end

    test "returns fewer than 3 shops when CSV has less than 3 valid entries", %{conn: conn} do
      user_x = 0.0
      user_y = 0.0

      mock_csv_source = fn ->
        {:ok,
         """
         Shop1,1.0,1.0
         Invalid,bad,data
         Shop2,2.0,2.0
         """}
      end

      conn =
        conn
        |> Plug.Conn.put_private(:csv_source, mock_csv_source)
        |> get(~p"/api/coffee-shops/nearest?x=#{user_x}&y=#{user_y}")

      assert %{
               "data" => shops
             } = json_response(conn, 200)

      assert length(shops) == 2
    end

    test "uses CSV source successfully", %{conn: conn} do
      user_x = 47.6
      user_y = -122.4

      request_tracker = self()

      tracking_csv_source = fn ->
        send(request_tracker, :source_accessed)

        {:ok,
         """
         Shop1,1.0,1.0
         """}
      end

      conn =
        conn
        |> Plug.Conn.put_private(:csv_source, tracking_csv_source)
        |> get(~p"/api/coffee-shops/nearest?x=#{user_x}&y=#{user_y}")

      assert json_response(conn, 200)

      assert_received :source_accessed
    end
  end
end

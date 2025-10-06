defmodule CoffeeAddicts.DistanceCalculatorTest do
  use ExUnit.Case, async: true

  alias CoffeeAddicts.DistanceCalculator
  alias CoffeeAddicts.CsvProcessor.CoffeeShop

  describe "find_closest/3" do
    test "returns the 3 closest shops from actual fixture data matching README example" do
      fixture_csv_content = File.read!("test/fixtures/coffee_shops.csv")
      {:ok, all_shops} = CoffeeAddicts.CsvProcessor.process_csv(fixture_csv_content)

      seattle_user_x = 47.6
      seattle_user_y = -122.4

      assert {:ok, closest_shops} =
               DistanceCalculator.find_closest(all_shops, seattle_user_x, seattle_user_y)

      expected_shop_count = 3
      assert length(closest_shops) == expected_shop_count

      [first_closest, second_closest, third_closest] = closest_shops

      assert %{name: "Starbucks Seattle2"} = first_closest
      assert %{name: "Starbucks Seattle"} = second_closest
      assert %{name: "Starbucks SF"} = third_closest
    end

    test "returns the 3 closest coffee shops to user coordinates" do
      worldwide_shops = [
        %CoffeeShop{name: "Starbucks Seattle", x: 47.5809, y: -122.3160},
        %CoffeeShop{name: "Starbucks SF", x: 37.5209, y: -122.3340},
        %CoffeeShop{name: "Starbucks Moscow", x: 55.752047, y: 37.595242},
        %CoffeeShop{name: "Starbucks Seattle2", x: 47.5869, y: -122.3368},
        %CoffeeShop{name: "Starbucks Rio", x: -22.923489, y: -43.234418},
        %CoffeeShop{name: "Starbucks Sydney", x: -33.871843, y: 151.206767}
      ]

      seattle_user_x = 47.6
      seattle_user_y = -122.4

      assert {:ok, closest_shops} =
               DistanceCalculator.find_closest(worldwide_shops, seattle_user_x, seattle_user_y)

      expected_count = 3
      assert length(closest_shops) == expected_count

      [first_shop, second_shop, third_shop] = closest_shops

      assert %{name: "Starbucks Seattle2", distance: first_distance} = first_shop
      assert %{name: "Starbucks Seattle", distance: second_distance} = second_shop
      assert %{name: "Starbucks SF", distance: third_distance} = third_shop

      assert first_distance < second_distance
      assert second_distance < third_distance

      assert is_float(first_distance)
      assert Float.round(first_distance, 4) == first_distance
    end

    test "returns fewer than 3 shops if less than 3 available" do
      two_shops = [
        %CoffeeShop{name: "Shop1", x: 1.0, y: 1.0},
        %CoffeeShop{name: "Shop2", x: 2.0, y: 2.0}
      ]

      origin_x = 0.0
      origin_y = 0.0

      assert {:ok, closest_shops} = DistanceCalculator.find_closest(two_shops, origin_x, origin_y)

      expected_count = 2
      assert length(closest_shops) == expected_count
    end

    test "returns empty list when no shops available" do
      empty_shop_list = []
      origin_x = 0.0
      origin_y = 0.0

      assert {:ok, []} = DistanceCalculator.find_closest(empty_shop_list, origin_x, origin_y)
    end

    test "uses custom distance calculator function via dependency injection" do
      three_shops = [
        %CoffeeShop{name: "Shop1", x: 1.0, y: 1.0},
        %CoffeeShop{name: "Shop2", x: 2.0, y: 2.0},
        %CoffeeShop{name: "Shop3", x: 3.0, y: 3.0}
      ]

      fixed_distance_calculator = fn shop, _user_x, _user_y ->
        case shop.name do
          "Shop1" -> 100.0
          "Shop2" -> 50.0
          "Shop3" -> 25.0
        end
      end

      origin_x = 0.0
      origin_y = 0.0

      assert {:ok, closest_shops} =
               DistanceCalculator.find_closest(three_shops, origin_x, origin_y,
                 distance_fn: fixed_distance_calculator
               )

      [closest_shop, second_shop, third_shop] = closest_shops

      assert %{name: "Shop3", distance: 25.0} = closest_shop
      assert %{name: "Shop2", distance: 50.0} = second_shop
      assert %{name: "Shop1", distance: 100.0} = third_shop
    end

    test "returns error for invalid user coordinates" do
      single_shop = [%CoffeeShop{name: "Shop1", x: 1.0, y: 1.0}]
      invalid_x_coordinate = "invalid"
      invalid_y_coordinate = "invalid"
      valid_y = 0.0
      valid_x = 0.0

      expected_x_error = {:error, {:invalid_coordinates, "User X coordinate must be a number"}}
      expected_y_error = {:error, {:invalid_coordinates, "User Y coordinate must be a number"}}

      assert expected_x_error ==
               DistanceCalculator.find_closest(single_shop, invalid_x_coordinate, valid_y)

      assert expected_y_error ==
               DistanceCalculator.find_closest(single_shop, valid_x, invalid_y_coordinate)
    end

    test "handles shops with same distance (stable sort)" do
      equidistant_shops = [
        %CoffeeShop{name: "Shop1", x: 1.0, y: 0.0},
        %CoffeeShop{name: "Shop2", x: 0.0, y: 1.0},
        %CoffeeShop{name: "Shop3", x: -1.0, y: 0.0}
      ]

      origin_x = 0.0
      origin_y = 0.0

      assert {:ok, closest_shops} =
               DistanceCalculator.find_closest(equidistant_shops, origin_x, origin_y)

      expected_count = 3
      assert length(closest_shops) == expected_count

      distances = Enum.map(closest_shops, & &1.distance)
      expected_distance = 1.0
      assert Enum.all?(distances, &(&1 == expected_distance))
    end
  end

  describe "calculate_distance/3" do
    test "calculates Euclidean distance on a plane" do
      shop_at_3_4 = %CoffeeShop{name: "Test", x: 3.0, y: 4.0}
      origin_x = 0.0
      origin_y = 0.0

      calculated_distance = DistanceCalculator.calculate_distance(shop_at_3_4, origin_x, origin_y)

      expected_distance = 5.0
      assert calculated_distance == expected_distance
    end

    test "rounds distance to 4 decimal places" do
      shop_at_1_1 = %CoffeeShop{name: "Test", x: 1.0, y: 1.0}
      origin_x = 0.0
      origin_y = 0.0

      calculated_distance = DistanceCalculator.calculate_distance(shop_at_1_1, origin_x, origin_y)

      expected_rounded_sqrt_2 = 1.4142
      assert calculated_distance == expected_rounded_sqrt_2
    end

    test "handles negative coordinates" do
      shop_at_negative_3_negative_4 = %CoffeeShop{name: "Test", x: -3.0, y: -4.0}
      origin_x = 0.0
      origin_y = 0.0

      calculated_distance =
        DistanceCalculator.calculate_distance(shop_at_negative_3_negative_4, origin_x, origin_y)

      expected_distance = 5.0
      assert calculated_distance == expected_distance
    end

    test "returns 0.0 when shop is at user location" do
      shop_at_5_10 = %CoffeeShop{name: "Test", x: 5.0, y: 10.0}
      user_x = 5.0
      user_y = 10.0

      calculated_distance = DistanceCalculator.calculate_distance(shop_at_5_10, user_x, user_y)

      expected_zero_distance = 0.0
      assert calculated_distance == expected_zero_distance
    end
  end
end

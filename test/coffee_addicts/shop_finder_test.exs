defmodule CoffeeAddicts.ShopFinderTest do
  use ExUnit.Case, async: true

  alias CoffeeAddicts.ShopFinder

  describe "find_closest_from_csv/3" do
    test "finds 3 closest shops from actual CSV fixture file" do
      fixture_csv_content = File.read!("test/fixtures/coffee_shops.csv")
      seattle_user_x = 47.6
      seattle_user_y = -122.4

      assert {:ok, closest_shops} =
               ShopFinder.find_closest_from_csv(
                 fixture_csv_content,
                 seattle_user_x,
                 seattle_user_y
               )

      expected_shop_count = 3
      assert length(closest_shops) == expected_shop_count

      [closest_shop, second_closest_shop, third_closest_shop] = closest_shops

      assert %{name: "Starbucks Seattle2", distance: closest_distance} = closest_shop
      assert %{name: "Starbucks Seattle", distance: second_distance} = second_closest_shop
      assert %{name: "Starbucks SF", distance: third_distance} = third_closest_shop

      assert closest_distance < second_distance
      assert second_distance < third_distance

      assert Float.round(closest_distance, 4) == closest_distance
      assert Float.round(second_distance, 4) == second_distance
      assert Float.round(third_distance, 4) == third_distance
    end

    test "finds 3 closest shops from CSV content" do
      world_starbucks_csv = """
      Starbucks Seattle,47.5809,-122.3160
      Starbucks SF,37.5209,-122.3340
      Starbucks Moscow,55.752047,37.595242
      Starbucks Seattle2,47.5869,-122.3368
      Starbucks Rio,-22.923489,-43.234418
      Starbucks Sydney,-33.871843,151.206767
      """

      seattle_user_x = 47.6
      seattle_user_y = -122.4

      assert {:ok, closest_shops} =
               ShopFinder.find_closest_from_csv(
                 world_starbucks_csv,
                 seattle_user_x,
                 seattle_user_y
               )

      expected_count = 3
      assert length(closest_shops) == expected_count

      [first_shop, second_shop, third_shop] = closest_shops

      assert %{name: "Starbucks Seattle2", distance: first_distance} = first_shop
      assert %{name: "Starbucks Seattle", distance: second_distance} = second_shop
      assert %{name: "Starbucks SF", distance: third_distance} = third_shop

      assert first_distance < second_distance
      assert second_distance < third_distance
      assert Float.round(first_distance, 4) == first_distance
    end

    test "processes large CSV in parallel batches efficiently" do
      total_shops = 10_000
      shop_lines = for i <- 1..total_shops, do: "Shop#{i},#{i * 1.0},#{i * 2.0}"
      large_csv_content = Enum.join(shop_lines, "\n")

      origin_x = 0.0
      origin_y = 0.0
      batch_size = 100

      assert {:ok, closest_shops} =
               ShopFinder.find_closest_from_csv(
                 large_csv_content,
                 origin_x,
                 origin_y,
                 batch_size: batch_size
               )

      expected_result_count = 3
      assert length(closest_shops) == expected_result_count

      closest_shop_to_origin = Enum.at(closest_shops, 0)
      assert %{name: "Shop1"} = closest_shop_to_origin
    end

    test "filters out malformed entries while finding closest" do
      csv_with_valid_and_invalid_entries = """
      Valid Shop1,1.0,1.0
      Invalid,not_a_number,2.0
      Valid Shop2,2.0,2.0
      Missing,3.0
      Valid Shop3,3.0,3.0
      ,4.0,4.0
      Valid Shop4,4.0,4.0
      """

      origin_x = 0.0
      origin_y = 0.0

      assert {:ok, closest_shops} =
               ShopFinder.find_closest_from_csv(
                 csv_with_valid_and_invalid_entries,
                 origin_x,
                 origin_y
               )

      expected_count = 3
      assert length(closest_shops) == expected_count

      shop_names = Enum.map(closest_shops, & &1.name)
      assert "Valid Shop1" in shop_names
      assert "Valid Shop2" in shop_names
      assert "Valid Shop3" in shop_names
    end

    test "handles empty CSV" do
      empty_csv = ""
      origin_x = 0.0
      origin_y = 0.0

      assert {:ok, []} = ShopFinder.find_closest_from_csv(empty_csv, origin_x, origin_y)
    end

    test "returns fewer than 3 if CSV has less than 3 valid entries" do
      csv_with_two_valid_shops = """
      Shop1,1.0,1.0
      Invalid,bad,data
      Shop2,2.0,2.0
      """

      origin_x = 0.0
      origin_y = 0.0

      assert {:ok, closest_shops} =
               ShopFinder.find_closest_from_csv(csv_with_two_valid_shops, origin_x, origin_y)

      expected_count = 2
      assert length(closest_shops) == expected_count
    end

    test "returns error for invalid user coordinates" do
      valid_csv = "Shop1,1.0,1.0\n"
      invalid_x_coordinate = "invalid"
      invalid_y_coordinate = "invalid"
      valid_y = 0.0
      valid_x = 0.0

      expected_x_error = {:error, {:invalid_coordinates, "User X coordinate must be a number"}}
      expected_y_error = {:error, {:invalid_coordinates, "User Y coordinate must be a number"}}

      assert expected_x_error ==
               ShopFinder.find_closest_from_csv(valid_csv, invalid_x_coordinate, valid_y)

      assert expected_y_error ==
               ShopFinder.find_closest_from_csv(valid_csv, valid_x, invalid_y_coordinate)
    end

    test "uses custom batch processor via dependency injection" do
      four_shops_csv = """
      Shop1,1.0,1.0
      Shop2,2.0,2.0
      Shop3,3.0,3.0
      Shop4,4.0,4.0
      """

      test_process = self()
      lines_per_batch = 2

      tracking_batch_processor = fn batch, user_x, user_y ->
        batch_line_count = length(batch)
        send(test_process, {:batch_processed, batch_line_count})
        ShopFinder.process_batch(batch, user_x, user_y)
      end

      origin_x = 0.0
      origin_y = 0.0

      assert {:ok, _closest_shops} =
               ShopFinder.find_closest_from_csv(
                 four_shops_csv,
                 origin_x,
                 origin_y,
                 batch_size: lines_per_batch,
                 batch_processor: tracking_batch_processor
               )

      expected_lines_in_batch = 2
      assert_received {:batch_processed, ^expected_lines_in_batch}
      assert_received {:batch_processed, ^expected_lines_in_batch}
    end

    test "correctly merges top 3 from multiple batches" do
      csv_with_close_and_far_shops = """
      Far1,100.0,100.0
      Far2,101.0,101.0
      Close1,0.1,0.1
      Far3,102.0,102.0
      Close2,0.2,0.2
      Far4,103.0,103.0
      Close3,0.3,0.3
      """

      origin_x = 0.0
      origin_y = 0.0
      small_batch_size = 2

      assert {:ok, global_closest_shops} =
               ShopFinder.find_closest_from_csv(
                 csv_with_close_and_far_shops,
                 origin_x,
                 origin_y,
                 batch_size: small_batch_size
               )

      expected_count = 3
      assert length(global_closest_shops) == expected_count

      shop_names = Enum.map(global_closest_shops, & &1.name)
      assert "Close1" in shop_names
      assert "Close2" in shop_names
      assert "Close3" in shop_names
    end
  end

  describe "process_batch/3" do
    test "processes batch and returns top 3 closest shops" do
      four_shop_batch = [
        "Shop1,1.0,1.0",
        "Shop2,5.0,5.0",
        "Shop3,2.0,2.0",
        "Shop4,10.0,10.0"
      ]

      origin_x = 0.0
      origin_y = 0.0

      batch_top_3 = ShopFinder.process_batch(four_shop_batch, origin_x, origin_y)

      expected_count = 3
      assert length(batch_top_3) == expected_count

      [first_closest, second_closest, third_closest] = batch_top_3

      assert %{name: "Shop1"} = first_closest
      assert %{name: "Shop3"} = second_closest
      assert %{name: "Shop2"} = third_closest
    end

    test "filters out malformed entries in batch" do
      batch_with_valid_and_invalid_lines = [
        "Valid1,1.0,1.0",
        "Invalid,bad,data",
        "Valid2,2.0,2.0",
        ",3.0,3.0"
      ]

      origin_x = 0.0
      origin_y = 0.0

      valid_shops_from_batch =
        ShopFinder.process_batch(batch_with_valid_and_invalid_lines, origin_x, origin_y)

      expected_valid_count = 2
      assert length(valid_shops_from_batch) == expected_valid_count

      shop_names = Enum.map(valid_shops_from_batch, & &1.name)
      assert "Valid1" in shop_names
      assert "Valid2" in shop_names
    end

    test "returns fewer than 3 if batch has less than 3 valid entries" do
      batch_with_one_valid_shop = ["Shop1,1.0,1.0", "Invalid,bad,data"]
      origin_x = 0.0
      origin_y = 0.0

      shops_from_batch = ShopFinder.process_batch(batch_with_one_valid_shop, origin_x, origin_y)

      expected_count = 1
      assert length(shops_from_batch) == expected_count
    end

    test "returns empty list for batch with no valid entries" do
      batch_with_only_invalid_lines = ["Invalid1,bad,data", "Invalid2,bad,data"]
      origin_x = 0.0
      origin_y = 0.0

      shops_from_batch =
        ShopFinder.process_batch(batch_with_only_invalid_lines, origin_x, origin_y)

      assert shops_from_batch == []
    end
  end
end

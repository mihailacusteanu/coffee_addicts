defmodule CoffeeAddicts.CsvProcessorTest do
  use ExUnit.Case, async: true

  alias CoffeeAddicts.CsvProcessor

  describe "process_csv/2" do
    test "successfully processes actual CSV fixture file" do
      fixture_csv_content = File.read!("test/fixtures/coffee_shops.csv")

      assert {:ok, parsed_shops} = CsvProcessor.process_csv(fixture_csv_content)

      expected_shop_count = 6
      assert length(parsed_shops) == expected_shop_count

      shop_names = Enum.map(parsed_shops, & &1.name)
      assert "Starbucks Seattle" in shop_names
      assert "Starbucks SF" in shop_names
      assert "Starbucks Moscow" in shop_names
      assert "Starbucks Seattle2" in shop_names
      assert "Starbucks Rio De Janeiro" in shop_names
      assert "Starbucks Sydney" in shop_names

      seattle_shop = Enum.find(parsed_shops, &(&1.name == "Starbucks Seattle"))
      expected_seattle_coordinates = %{x: 47.5809, y: -122.3160}
      assert ^expected_seattle_coordinates = Map.take(seattle_shop, [:x, :y])
    end

    test "successfully processes valid CSV data into coffee shop structs" do
      csv_content = """
      Starbucks Seattle,47.5809,-122.3160
      Starbucks SF,37.5209,-122.3340
      Starbucks Moscow,55.752047,37.595242
      """

      assert {:ok, shops} = CsvProcessor.process_csv(csv_content)
      assert length(shops) == 3

      assert %{name: "Starbucks Seattle", x: 47.5809, y: -122.3160} = Enum.at(shops, 0)
      assert %{name: "Starbucks SF", x: 37.5209, y: -122.3340} = Enum.at(shops, 1)
      assert %{name: "Starbucks Moscow", x: 55.752047, y: 37.595242} = Enum.at(shops, 2)
    end

    test "processes CSV in batches using custom batch size" do
      four_shops_csv = """
      Shop1,1.0,2.0
      Shop2,3.0,4.0
      Shop3,5.0,6.0
      Shop4,7.0,8.0
      """

      test_process = self()
      lines_per_batch = 2

      tracking_batch_processor = fn batch ->
        batch_line_count = length(batch)
        send(test_process, {:batch_processed, batch_line_count})
        Enum.map(batch, &CsvProcessor.parse_line/1)
      end

      assert {:ok, all_shops} =
               CsvProcessor.process_csv(four_shops_csv,
                 batch_size: lines_per_batch,
                 batch_processor: tracking_batch_processor
               )

      expected_total_shops = 4
      assert length(all_shops) == expected_total_shops

      expected_lines_in_batch = 2
      assert_received {:batch_processed, ^expected_lines_in_batch}
      assert_received {:batch_processed, ^expected_lines_in_batch}
    end

    test "filters out malformed CSV entries" do
      csv_content = """
      Valid Shop,1.0,2.0
      Invalid Shop,not_a_number,2.0
      Another Valid,3.0,4.0
      Missing Coordinate,5.0
      ,1.0,2.0
      Also Valid,6.0,7.0
      """

      assert {:ok, shops} = CsvProcessor.process_csv(csv_content)
      assert length(shops) == 3

      assert %{name: "Valid Shop", x: 1.0, y: 2.0} = Enum.at(shops, 0)
      assert %{name: "Another Valid", x: 3.0, y: 4.0} = Enum.at(shops, 1)
      assert %{name: "Also Valid", x: 6.0, y: 7.0} = Enum.at(shops, 2)
    end

    test "handles empty CSV content" do
      assert {:ok, []} = CsvProcessor.process_csv("")
    end

    test "handles CSV with only whitespace" do
      assert {:ok, []} = CsvProcessor.process_csv("   \n  \n  ")
    end

    test "handles CSV with all malformed entries" do
      csv_content = """
      Invalid,not,a,number
      Also Invalid
      ,
      """

      assert {:ok, []} = CsvProcessor.process_csv(csv_content)
    end

    test "processes very large CSV in parallel batches" do
      total_shops = 1000
      shop_lines = for i <- 1..total_shops, do: "Shop#{i},#{i * 1.0},#{i * 2.0}"
      large_csv_content = Enum.join(shop_lines, "\n")
      batch_size = 100

      assert {:ok, parsed_shops} =
               CsvProcessor.process_csv(large_csv_content, batch_size: batch_size)

      assert length(parsed_shops) == total_shops
    end
  end

  describe "parse_line/1" do
    test "successfully parses a valid CSV line" do
      line = "Starbucks Seattle,47.5809,-122.3160"

      assert {:ok, shop} = CsvProcessor.parse_line(line)
      assert shop.name == "Starbucks Seattle"
      assert shop.x == 47.5809
      assert shop.y == -122.3160
    end

    test "returns error for line with invalid float" do
      line = "Invalid Shop,not_a_float,123.45"

      assert {:error, {:csv_parse_error, _message}} = CsvProcessor.parse_line(line)
    end

    test "returns error for line with missing fields" do
      line = "Invalid Shop,123.45"

      assert {:error, {:csv_parse_error, _message}} = CsvProcessor.parse_line(line)
    end

    test "returns error for line with empty name" do
      line = ",123.45,67.89"

      assert {:error, {:csv_parse_error, _message}} = CsvProcessor.parse_line(line)
    end

    test "returns error for empty line" do
      assert {:error, {:csv_parse_error, _message}} = CsvProcessor.parse_line("")
    end

    test "handles lines with extra whitespace" do
      line = " Starbucks Seattle , 47.5809 , -122.3160 "

      assert {:ok, shop} = CsvProcessor.parse_line(line)
      assert shop.name == "Starbucks Seattle"
      assert shop.x == 47.5809
      assert shop.y == -122.3160
    end
  end
end

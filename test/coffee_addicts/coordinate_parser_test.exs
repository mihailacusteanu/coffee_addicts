defmodule CoffeeAddicts.CoordinateParserTest do
  use ExUnit.Case, async: true

  alias CoffeeAddicts.CoordinateParser

  describe "parse/1" do
    test "successfully parses valid coordinates" do
      params = %{"x" => "47.6", "y" => "-122.4"}

      assert {:ok, {47.6, -122.4}} = CoordinateParser.parse(params)
    end

    test "parses integer values as floats" do
      params = %{"x" => "47", "y" => "-122"}

      assert {:ok, {47.0, -122.0}} = CoordinateParser.parse(params)
    end

    test "returns error when x coordinate is missing" do
      params = %{"y" => "-122.4"}

      assert {:error, {:missing_param, "x"}} = CoordinateParser.parse(params)
    end

    test "returns error when y coordinate is missing" do
      params = %{"x" => "47.6"}

      assert {:error, {:missing_param, "y"}} = CoordinateParser.parse(params)
    end

    test "returns error when x coordinate is not a number" do
      params = %{"x" => "not_a_number", "y" => "-122.4"}

      assert {:error, {:invalid_param, "x"}} = CoordinateParser.parse(params)
    end

    test "returns error when y coordinate is not a number" do
      params = %{"x" => "47.6", "y" => "not_a_number"}

      assert {:error, {:invalid_param, "y"}} = CoordinateParser.parse(params)
    end

    test "handles negative coordinates" do
      params = %{"x" => "-47.6", "y" => "-122.4"}

      assert {:ok, {-47.6, -122.4}} = CoordinateParser.parse(params)
    end

    test "handles zero coordinates" do
      params = %{"x" => "0.0", "y" => "0.0"}

      assert {:ok, {0.0, 0.0}} = CoordinateParser.parse(params)
    end
  end
end

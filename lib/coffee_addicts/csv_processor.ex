defmodule CoffeeAddicts.CsvProcessor do
  @moduledoc """
  Processes CSV data containing coffee shop information.
  Handles large files by processing them in batches using parallel processes.
  """

  defmodule CoffeeShop do
    @moduledoc """
    Represents a coffee shop with name and coordinates.
    """
    defstruct [:name, :x, :y]

    @type t :: %__MODULE__{
            name: String.t(),
            x: float(),
            y: float()
          }
  end

  @default_batch_size 100

  @doc """
  Processes CSV content and returns a list of coffee shops.

  ## Parameters
    - csv_content: String containing CSV data (format: Name,X,Y)
    - opts: Keyword list of options
      - :batch_size - Number of lines to process per batch (default: 100)
      - :batch_processor - Function for processing batches (for dependency injection)

  ## Returns
    - {:ok, [%CoffeeShop{}]} on success
    - Malformed entries are filtered out

  ## Examples
      iex> CsvProcessor.process_csv("Starbucks,1.0,2.0\\nCafe,3.0,4.0")
      {:ok, [%CoffeeShop{name: "Starbucks", x: 1.0, y: 2.0}, %CoffeeShop{name: "Cafe", x: 3.0, y: 4.0}]}
  """
  @spec process_csv(String.t(), keyword()) :: {:ok, [CoffeeShop.t()]}
  def process_csv(csv_content, opts \\ []) do
    batch_size = Keyword.get(opts, :batch_size, @default_batch_size)
    batch_processor = Keyword.get(opts, :batch_processor, &default_batch_processor/1)

    shops =
      csv_content
      |> parse_lines()
      |> process_in_batches(batch_size, batch_processor)
      |> extract_valid_shops()

    {:ok, shops}
  end

  defp parse_lines(csv_content) do
    csv_content
    |> String.split("\n", trim: true)
    |> Enum.map(&String.trim/1)
    |> Enum.reject(&(&1 == ""))
  end

  defp process_in_batches(lines, batch_size, batch_processor) do
    lines
    |> Enum.chunk_every(batch_size)
    |> Task.async_stream(batch_processor, ordered: true)
    |> Enum.flat_map(fn {:ok, results} -> results end)
  end

  defp extract_valid_shops(results) do
    results
    |> Enum.filter(&match?({:ok, _}, &1))
    |> Enum.map(fn {:ok, shop} -> shop end)
  end

  @doc """
  Parses a single CSV line into a CoffeeShop struct.

  ## Parameters
    - line: String containing a CSV line (format: Name,X,Y)

  ## Returns
    - {:ok, %CoffeeShop{}} on success
    - {:error, {:csv_parse_error, message}} on failure

  ## Examples
      iex> CsvProcessor.parse_line("Starbucks,1.0,2.0")
      {:ok, %CoffeeShop{name: "Starbucks", x: 1.0, y: 2.0}}

      iex> CsvProcessor.parse_line("Invalid,not_a_number,2.0")
      {:error, {:csv_parse_error, "Invalid float value"}}
  """
  @spec parse_line(String.t()) :: {:ok, CoffeeShop.t()} | {:error, {atom(), String.t()}}
  def parse_line(line) do
    with trimmed <- String.trim(line),
         true <- trimmed != "" || {:error, "Empty line"},
         parts <- String.split(trimmed, ","),
         [name_raw, x_raw, y_raw] <- parts,
         name <- String.trim(name_raw),
         true <- name != "" || {:error, "Empty name"},
         {x, ""} <- Float.parse(String.trim(x_raw)),
         {y, ""} <- Float.parse(String.trim(y_raw)) do
      {:ok, %CoffeeShop{name: name, x: x, y: y}}
    else
      {:error, reason} when is_binary(reason) ->
        {:error, {:csv_parse_error, reason}}

      _ ->
        {:error, {:csv_parse_error, "Invalid CSV format"}}
    end
  end

  @doc false
  def default_batch_processor(batch) do
    Enum.map(batch, &parse_line/1)
  end
end

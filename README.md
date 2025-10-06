# CoffeeAddicts

## Overview
You have been hired by a company that builds an app for coffee addicts. You are
responsible for writing a REST API that offers the possibility to take the user's
coordinates and return a list of the three closest coffee shops (including distance
from the user) in order from the closest to farthest.

### Data
The coffee shops are stored in a remote CSV having these columns: Name,X,Y

The quality of data in this list of coffee shops may vary. Malformed entries should be
handled appropriately.

Notice that the data file will be read from a network location (ex:
https://static.reasig.ro/interview/coffee_shops_exerceise/coffee_shops.csv )

## Getting Started

### Prerequisites
- Elixir 1.14 or higher
- Erlang/OTP

### Installation

1. Install dependencies:
```bash
mix deps.get
```

2. Run tests:
```bash
mix test
```

3. Start the server:
```bash
mix phx.server
```

The API will be available at `http://localhost:4000`

## API Usage

### Endpoint
```
GET /api/coffee-shops/nearest
```

### Query Parameters
- `x` (required): User's X coordinate (float)
- `y` (required): User's Y coordinate (float)

### Example Request
```bash
curl "http://localhost:4000/api/coffee-shops/nearest?x=47.6&y=-122.4"
```

### Example Response
```json
{
  "data": [
    {
      "name": "Starbucks Seattle2",
      "x": 47.5869,
      "y": -122.3368,
      "distance": 0.0332
    },
    {
      "name": "Starbucks Seattle",
      "x": 47.5809,
      "y": -122.316,
      "distance": 0.0849
    },
    {
      "name": "Starbucks SF",
      "x": 37.5209,
      "y": -122.334,
      "distance": 10.0801
    }
  ]
}
```

## API Response Format

A list of the three closest coffee shops (name, location and distance from the user)
in order from the closest to farthest.

These distances should be rounded to four decimal places.

Assume all coordinates lie on a plane.

### Error Responses

**400 Bad Request** - Missing or invalid parameters:
```json
{
  "error": "Missing required parameter: x"
}
```

**503 Service Unavailable** - Failed to fetch coffee shop data:
```json
{
  "error": "Failed to fetch coffee shop data"
}
```

## Configuration

The CSV URL can be configured in `config/config.exs`:
```elixir
config :coffee_addicts, csv_url: "https://your-custom-url/coffee_shops.csv"
```

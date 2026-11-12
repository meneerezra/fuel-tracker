# Fuel Tracker [WIP]
The idea of this app to track how much km I have driven. I then convert it to fuel in liters and calculate how much money it cost so I can pay my dad back when I drive his car. My dad can also look at this information. It uses a 16 digit number for authentication inspired by Mullvad VPN. I chose it because it is easier then logging in for my father every 2 weeks.

## Features
- [ ] App with all features
- [ ] Live tracking
- [x] Get weekly fuel price
- [x] Multiple cars per user
- [x] Share cars between users
- [x] Price per km and price per threshold (for example: what 100 km costs)
- [x] Light and dark mode

## How it works
1. Add a car with its fuel type, consumption (liters per 100 km), country and km threshold.
2. The server fetches the latest weekly fuel price for that country from [fuel-prices.eu](https://www.fuel-prices.eu).
3. The cost is calculated as:

```
price_per_km        = fuel_price * consumption / 100
price_per_threshold = price_per_km * km_threshold
```

Supported fuel types: `diesel` and `e95` (petrol).

## Project structure
```
app/      Flutter app (Android)
server/   FastAPI server with a SQLite database
```

## Server
Requirements: Python 3.11+ and [uv](https://docs.astral.sh/uv/).

```sh
cd server
uv sync
uv run fastapi dev main.py
```

The API runs on `http://localhost:8000`. Interactive docs are at `http://localhost:8000/docs`.

On first start the server creates `database.db` and a superuser called "First admin". Its 16-digit auth token is stored in the `user` table. Use this token to create more users.

### Seed demo data
```sh
cd server
uv run python seed.py
```

Seeding appends to the existing database. Delete `database.db` first for a clean start. The script prints the auth tokens of the created users.

### Configuration
Optional environment variables:

| Variable | Default | Description |
| --- | --- | --- |
| `FUEL_PRICES_BASE_URL` | `https://www.fuel-prices.eu` | Fuel price API |
| `FUEL_PRICES_TIMEOUT` | `10` | Request timeout in seconds |
| `FUEL_PRICES_USER_AGENT` | `fuel-tracker/0.1` | User agent sent to the fuel price API |

## API
All endpoints need an `Authorization: Bearer <16-digit token>` header.

| Method | Endpoint | Description |
| --- | --- | --- |
| `GET` | `/v1/users/me` | Current user with owned and shared cars |
| `POST` | `/v1/users/` | Create a user (superuser only) |
| `POST` | `/v1/cars/` | Create a car |
| `GET` | `/v1/cars/{car_id}` | Get a car |
| `PUT` | `/v1/cars/` | Edit a car |
| `DELETE` | `/v1/cars/` | Delete a car |
| `GET` | `/v1/cars/{car_id}/price` | Price per km and per threshold |

## App
Requirements: [Flutter](https://docs.flutter.dev/get-started/install) (Dart SDK 3.13+).

```sh
cd app
flutter pub get
flutter run
```

In the app, go to **Settings > Authentication** and fill in the server URL and your auth token. The token is stored in secure storage.

## Credits
Fuel prices are provided by [fuel-prices.eu](https://www.fuel-prices.eu).

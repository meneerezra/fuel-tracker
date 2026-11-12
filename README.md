# Fuel Tracker [WIP]
The idea of this app to track how much km I have driven. I then convert it to fuel in liters and calculate how much money it cost so I can pay my dad back when I drive his car. My dad can also look at this information. It uses a 16 digit number for authentication inspired by Mullvad VPN. I chose it because it is easier then logging in for my father every 2 weeks.

## Features
- [x] App with all features
- [x] Live tracking with GPS
- [x] Get weekly fuel price
- [x] Multiple cars per user
- [x] Share cars between users (view only)
- [x] Price per km and price per threshold (for example: what 100 km costs)
- [x] Amount owed and a "Paid" button that resets the trip
- [x] Server settings for superusers: manage all accounts and cars
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

The amount owed is `fuel_price * consumption / 100 * km_driven`. After paying, tap **Paid** to reset the trip (`km_driven`) to 0. The odometer (`total_km_driven`) is kept.

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

`fastapi dev` only listens on this computer. To reach the server from a phone on the same network, listen on all interfaces and use the computer's local IP in the app, for example `http://192.168.1.10:8000`:

```sh
uv run fastapi dev main.py --host 0.0.0.0
```

For a server that keeps running, use `uv run fastapi run main.py --host 0.0.0.0` instead of `fastapi dev`.

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
| `GET` | `/v1/users/` | All users with their cars (superuser only) |
| `POST` | `/v1/users/` | Create a user (superuser only) |
| `PUT` | `/v1/users/{user_id}` | Rename a user (superuser only) |
| `GET` | `/v1/users/{user_id}/token` | View a user's auth token (superuser only) |
| `DELETE` | `/v1/users/{user_id}` | Delete a user and the cars they own (superuser only, not your own account) |
| `POST` | `/v1/cars/` | Create a car |
| `GET` | `/v1/cars/{car_id}` | Get a car |
| `PUT` | `/v1/cars/` | Edit a car |
| `DELETE` | `/v1/cars/` | Delete a car |
| `GET` | `/v1/cars/{car_id}/price` | Fuel price, price per km and per threshold |
| `GET` | `/v1/cars/{car_id}/shares` | Users the car is shared with (owner only) |
| `POST` | `/v1/cars/{car_id}/shares` | Share the car with a user ID (owner only) |
| `DELETE` | `/v1/cars/{car_id}/shares/{user_id}` | Stop sharing. The owner can remove anyone, a shared user can remove themselves |

Users a car is shared with can only view it and get its price. Only the owner can change the car, share it or delete it. Superusers have owner rights on every car, and can see all accounts and cars in the app under **Settings > Server settings**.

Cars you cannot see return `404`, the same as cars that do not exist.

Input limits (`422` when not met):

| Field | Limit |
| --- | --- |
| `name` | 1 to 100 characters |
| `km_threshold`, `km_driven`, `total_km_driven` | 0 to 10,000,000, decimals allowed |
| `consumption` | 0 to 100 liters per 100 km |
| `country_code` | 2 letters |

## App
Requirements: [Flutter](https://docs.flutter.dev/get-started/install) (Dart SDK 3.13+).

```sh
cd app
flutter pub get
flutter run
```

In the app, go to **Settings > Authentication** and fill in the server URL and your auth token. Include `http://` in the URL, without it the app uses `https://`. The token is stored in secure storage.

### Tabs
- **Current car**: the car marked with a star in the Cars tab. Shows the trip, amount owed, prices, the km counter and GPS trips.
- **Cars**: owned and shared cars with search. Tap the star to make a car the current car, tap **Add car** to create one.
- **Settings**: dark mode, authentication and your user ID. Superusers also see **Server settings**.

### Sharing
To share a car, open it and tap **Share**, then enter the other user's ID. Users find their ID under **Settings > Your user ID**.

### GPS trips
On a car you own, tap **Start** to measure a trip with GPS. Tracking keeps running while the screen is locked, with a notification. Tap **Stop** to see the distance and time, correct the km if needed, and add them to the car or discard the trip.

- GPS fixes less accurate than 30 m are ignored. Movement smaller than the GPS accuracy (at least 5 m) is treated as drift, so standing still does not add km.
- The trip is kept in memory. It is lost when Android closes the app.
- In debug builds every GPS fix is logged with a `[Trip]` prefix (`adb logcat -s flutter`).

## Security
- The app talks to the server over plain HTTP (`usesCleartextTraffic`), so the auth token is sent unencrypted. This is fine on a home network. Put the server behind HTTPS before exposing it to the internet.
- Auth tokens are stored unencrypted in `database.db`, so superusers can view them. Keep this file private.
- `/docs` remembers the token in the browser (`persistAuthorization`). Only use it on your own computer.

## Credits
Fuel prices are provided by [fuel-prices.eu](https://www.fuel-prices.eu).
